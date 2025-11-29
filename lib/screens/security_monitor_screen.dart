import 'package:flutter/material.dart';
import 'dart:async';
import '../services/firebase_security_service.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';

class SecurityMonitorScreen extends StatefulWidget {
  final String pairingCode;

  const SecurityMonitorScreen({super.key, required this.pairingCode});

  @override
  State<SecurityMonitorScreen> createState() => _SecurityMonitorScreenState();
}

class _SecurityMonitorScreenState extends State<SecurityMonitorScreen> with WidgetsBindingObserver {
  final _securityService = FirebaseSecurityService();
  final _notificationService = NotificationService();
  List<Map<String, dynamic>> _alerts = [];
  bool _isPaired = false;
  bool _isValidating = true;
  List<String> _monitoredObjects = [];
  StreamSubscription? _alertsSubscription;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validateAndConnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't cancel subscription or stop monitoring here
    // Keep it running in background
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      debugPrint('SecurityMonitor: App resumed, refreshing data...');
      _refreshData();
    } else if (state == AppLifecycleState.paused) {
      // App going to background - monitoring continues
      debugPrint('SecurityMonitor: App paused, monitoring continues in background');
    }
  }

  Future<void> _validateAndConnect() async {
    setState(() => _isValidating = true);

    final isValid = await _securityService.validateCode(widget.pairingCode);

    if (!isValid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Invalid pairing code'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
      return;
    }

    final pairingInfo = await _securityService.getPairingInfo(widget.pairingCode);
    if (pairingInfo != null) {
      final objects = pairingInfo['selectedObjects'];
      if (objects is List) {
        _monitoredObjects = objects.cast<String>();
      }
    }

    // IMPORTANT: Store this pairing locally as a monitor device
    await _securityService.storePairingAsMonitor(widget.pairingCode, _monitoredObjects);

    // Save FCM token for monitor device
    final fcmToken = _notificationService.fcmToken;
    if (fcmToken != null) {
      try {
        await _securityService.saveFCMToken(widget.pairingCode, 'monitor', fcmToken);
        debugPrint('Monitor FCM token saved successfully');
      } catch (e) {
        debugPrint('Error saving monitor FCM token: $e');
      }
    }

    await _loadAlerts();

    if (mounted) {
      setState(() {
        _isPaired = true;
        _isValidating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Successfully paired with camera'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Start monitoring
      await _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    try {
      debugPrint('SecurityMonitor: Starting monitoring...');

      // Start monitoring in the service
      await _securityService.startMonitoring(widget.pairingCode, _monitoredObjects);

      // Setup alert stream for UI updates
      _alertsSubscription?.cancel();
      _alertsSubscription = _securityService.streamAlerts(widget.pairingCode).listen(
            (alerts) {
          if (mounted) {
            setState(() => _alerts = alerts);

            // Show notification for new alerts
            if (alerts.isNotEmpty) {
              final latestAlert = alerts.first;
              final objectLabel = latestAlert['objectLabel'] ?? 'Unknown';

              // Only notify if it's a monitored object
              if (_monitoredObjects.contains(objectLabel)) {
                _notificationService.sendSecurityAlert(
                  object: objectLabel,
                  confidence: (latestAlert['confidence'] ?? 0.0) as double,
                  pairingCode: widget.pairingCode,
                );
              }
            }
          }
        },
        onError: (error) {
          debugPrint('Error in alerts stream: $error');
        },
      );

      setState(() => _isMonitoring = true);

      debugPrint('SecurityMonitor: Monitoring started successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.white),
                SizedBox(width: 8),
                Text('Background notifications enabled'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting monitoring: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting monitoring: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await _securityService.getAlerts(widget.pairingCode);
      if (mounted) setState(() => _alerts = alerts);
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    }
  }

  String _formatTime(int timestamp) {
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final difference = DateTime.now().difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } catch (e) {
      return 'Unknown time';
    }
  }

  String _formatDetailedTime(int timestamp) {
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('EEEE, MMM d, yyyy \'at\' h:mm:ss a').format(dateTime);
    } catch (e) {
      return 'Unknown time';
    }
  }

  void _unpair() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Unpair Device?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to disconnect from this camera?\n\nNote: You can always reconnect using the same pairing code.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              // Stop monitoring
              await _securityService.stopMonitoring();

              // Cancel alert subscription
              await _alertsSubscription?.cancel();

              // Cancel notifications for this pairing
              await _notificationService.cancelAllNotifications();

              // Delete pairing
              await _securityService.deletePairing(widget.pairingCode);

              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close monitor screen

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device unpaired successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Unpair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() => _isValidating = true);

    final pairingInfo = await _securityService.getPairingInfo(widget.pairingCode);
    if (pairingInfo != null) {
      final objects = pairingInfo['selectedObjects'];
      if (objects is List) {
        setState(() => _monitoredObjects = objects.cast<String>());
      }
    }

    await _loadAlerts();
    setState(() => _isValidating = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isValidating && !_isPaired) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.tealAccent),
              SizedBox(height: 16),
              Text('Validating pairing code...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Don't stop monitoring when screen is popped
        // Monitoring continues in background
        debugPrint('SecurityMonitor: Screen popped, monitoring continues');
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildConnectionStatus(),
              const SizedBox(height: 20),
              _buildAlertsHeader(),
              const SizedBox(height: 8),
              Expanded(child: _buildAlertsList()),
              if (_alerts.isNotEmpty) _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Monitor Alerts',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh, color: Colors.tealAccent),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _isPaired ? _unpair : null,
            icon: Icon(Icons.link_off, color: _isPaired ? Colors.red : Colors.white24),
            tooltip: 'Unpair Device',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isPaired ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isPaired ? Colors.green : Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_isPaired ? Icons.check_circle : Icons.pending, color: _isPaired ? Colors.green : Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isPaired ? 'Connected to Camera' : 'Connecting...',
                          style: TextStyle(color: _isPaired ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        if (_isPaired && _isMonitoring)
                          const Icon(Icons.notifications_active, color: Colors.tealAccent, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Code: ${widget.pairingCode}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    if (_isMonitoring) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Background monitoring active',
                          style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_monitoredObjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Text(
              'Monitored objects: ${_monitoredObjects.join(', ')}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Alerts (${_alerts.length})', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          if (_alerts.isNotEmpty)
            TextButton(
              onPressed: _loadAlerts,
              child: const Row(
                children: [
                  Icon(Icons.refresh, color: Colors.tealAccent, size: 16),
                  SizedBox(width: 4),
                  Text('Refresh', style: TextStyle(color: Colors.tealAccent)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No alerts yet', style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text(
              _isPaired ? 'You\'ll be notified when objects are detected' : 'Waiting for connection...',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.3)),
            ),
            if (_isPaired && _isMonitoring) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active, color: Colors.tealAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Push notifications enabled', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) => _buildAlertItem(index),
    );
  }

  Widget _buildAlertItem(int index) {
    final alert = _alerts[index];
    final isNew = index == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isNew ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew ? Colors.red : Colors.red.withValues(alpha: 0.3),
          width: isNew ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isNew ? Colors.red.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isNew ? Icons.warning : Icons.notifications,
            color: isNew ? Colors.red : Colors.red.withValues(alpha: 0.7),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              alert['objectLabel']?.toString() ?? 'Unknown Object',
              style: TextStyle(
                color: Colors.white,
                fontWeight: isNew ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            if (alert['confidence'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(alert['confidence'] * 100).toInt()}%',
                  style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_formatTime(alert['timestamp'] as int? ?? 0), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              _formatDetailedTime(alert['timestamp'] as int? ?? 0),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
            ),
          ],
        ),
        trailing: isNew
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
          child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        )
            : Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.tealAccent, size: 16),
              const SizedBox(width: 8),
              Text('Latest: ${_alerts.first['objectLabel']}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          Text(
            _formatTime(_alerts.first['timestamp'] as int? ?? 0),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }
}