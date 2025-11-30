import 'package:flutter/material.dart';
import '../services/firebase_security_service.dart';
import '../screens/security_monitor_screen.dart';

/// Widget to display and manage paired security devices
class ManageSecurityDevicesSection extends StatefulWidget {
  const ManageSecurityDevicesSection({super.key});

  @override
  State<ManageSecurityDevicesSection> createState() => _ManageSecurityDevicesSectionState();
}

class _ManageSecurityDevicesSectionState extends State<ManageSecurityDevicesSection> {
  final _securityService = FirebaseSecurityService();
  List<Map<String, dynamic>> _activePairings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPairings();
  }

  Future<void> _loadPairings() async {
    setState(() => _isLoading = true);

    try {
      final pairings = await _securityService.getActivePairings();
      if (mounted) {
        setState(() {
          _activePairings = pairings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pairings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _viewMonitorAlerts(String code) async {
    try {
      // Validate pairing still exists
      final isValid = await _securityService.validateCode(code);

      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This pairing is no longer valid'),
              backgroundColor: Colors.red,
            ),
          );
        }
        await _securityService.deletePairing(code);
        _loadPairings();
        return;
      }

      // Navigate to monitor screen (always in normal mode for monitors)
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecurityMonitorScreen(pairingCode: code),
          ),
        ).then((_) => _loadPairings());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDevice(String code, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove Device?', style: TextStyle(color: Colors.white)),
        content: Text(
          role == 'camera'
              ? 'Are you sure you want to remove this camera device?\n\nYou can always pair again using the same code.'
              : 'Are you sure you want to remove this monitor device?\n\nYou can always pair again using the same code.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _securityService.deletePairing(code);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadPairings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing device: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.security, color: Colors.tealAccent, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Security Devices',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadPairings,
                icon: const Icon(Icons.refresh, color: Colors.tealAccent),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your paired cameras and monitors',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.tealAccent),
              ),
            )
          else if (_activePairings.isEmpty)
            _buildEmptyState()
          else
            _buildDevicesList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.devices_other,
              size: 60,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No Paired Devices',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pair devices from the Security tab',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.3),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList() {
    return Column(
      children: _activePairings.map((pairing) {
        final code = pairing['code'] as String? ?? 'Unknown';
        final role = pairing['role'] as String? ?? 'unknown';
        final selectedObjects = pairing['selectedObjects'] as List? ?? [];
        final createdAt = pairing['createdAt'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: role == 'camera'
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                role == 'camera' ? Icons.videocam : Icons.notifications_active,
                color: role == 'camera' ? Colors.blue : Colors.green,
                size: 24,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        role == 'camera' ? 'Camera Device' : 'Monitor Device',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 80,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (selectedObjects.isNotEmpty)
                  Text(
                    'Monitoring: ${selectedObjects.take(3).join(', ')}${selectedObjects.length > 3 ? '...' : ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                if (createdAt != null)
                  Text(
                    'Paired: ${_formatDate(createdAt)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 100,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ONLY show view alerts button for MONITOR devices
                  if (role == 'monitor')
                    IconButton(
                      onPressed: () => _viewMonitorAlerts(code),
                      icon: const Icon(
                        Icons.notifications,
                        color: Colors.tealAccent,
                        size: 20,
                      ),
                      tooltip: 'View Alerts',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  // Delete button for ALL devices
                  IconButton(
                    onPressed: () => _deleteDevice(code, role),
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    tooltip: 'Remove Device',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Recently';
    }
  }
}

