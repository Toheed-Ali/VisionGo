/// Security Camera Screen — Live YOLO detection with alert dispatch.
///
/// This is the “camera” side of VisionGo’s security system. It:
///   1. Initialises the device camera and the YOLO model.
///   2. Creates a pairing entry in Firebase Realtime Database.
///   3. Runs object detection every 2.5 seconds via a periodic timer.
///   4. When a user-selected object is detected, it:
///      – Saves an alert to Firebase (`security-pairings/{code}/alerts`)
///      – Shows a local notification on the camera device
///      – Sends an FCM push notification to every paired monitor device
///      – Saves the captured image to the device gallery
///   5. Provides a bottom-sheet UI for selecting which COCO objects to monitor.
///
/// The screen also listens for real-time changes to the monitors node so
/// that newly paired monitors immediately receive alerts.
library;

// Import necessary packages
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:camera/camera.dart'; // Camera functionality for live feed
import 'dart:async'; // For asynchronous operations and timers
import 'dart:io'; // For file operations
import 'package:photo_manager/photo_manager.dart'; // For saving images to gallery
import '../services/yolo_detector.dart'; // YOLO object detection service
import '../services/firebase_security_service.dart'; // Firebase integration for security alerts
import '../services/notification_service.dart';
import '../services/fcm_api_service.dart';

/// Stateful camera screen that manages YOLO detection, alert dispatch,
/// and Firebase pairing for the security system.
class SecurityCameraScreen extends StatefulWidget {
  /// Unique 8-character pairing code shared with monitor devices.
  final String pairingCode;
  const SecurityCameraScreen({
    super.key,
    required this.pairingCode, // Required pairing code passed from previous screen
  });

  @override
  State<SecurityCameraScreen> createState() => _SecurityCameraScreenState();
}

// State class that manages the security camera functionality
class _SecurityCameraScreenState extends State<SecurityCameraScreen> {
  // Camera controller to manage camera operations
  CameraController? _cameraController;
  // Flag to track if camera is initialized and ready
  bool _isInitialized = false;
  // Flag to prevent multiple simultaneous detections
  bool _isDetecting = false;
  // Track flash state (on/off)
  bool _isFlashOn = false;
  // Store current object detection results
  List<Detection> _detections = [];
  // Timer for periodic object detection
  Timer? _detectionTimer;
  // List of objects user wants to monitor for alerts
  List<String> _selectedObjects = [];
  // Store the size of camera preview for proper scaling
  Size? _previewSize;
  // Path to the last captured image for detection
  String? _lastImagePath;

  // Firebase service for security alerts and pairing management
  final FirebaseSecurityService _securityService = FirebaseSecurityService();

  final NotificationService _notificationService = NotificationService();
  final FCMApiService _fcmApiService = FCMApiService();
  
  List<Map<String, dynamic>> _monitorDevices = []; // Store all monitor 
  // Complete list of all objects that YOLO can detect (COCO dataset)
  final List<String> _allObjects = [
    'person', 'chair', 'couch', 'potted plant', 'bed', 'dining table',
    'toilet', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone',
    'airplane', 'apple', 'backpack', 'banana', 'baseball bat', 'baseball glove',
    'bear', 'bench', 'bicycle', 'bird', 'boat', 'book', 'bottle', 'bowl',
    'broccoli', 'bus', 'cake', 'car', 'carrot', 'cat', 'clock', 'cow', 'cup',
    'dog', 'donut', 'elephant', 'fire hydrant', 'fork', 'frisbee', 'giraffe',
    'hair drier', 'handbag', 'horse', 'hot dog', 'kite', 'knife', 'microwave',
    'motorcycle', 'orange', 'oven', 'parking meter', 'pizza', 'refrigerator',
    'sandwich', 'scissors', 'sheep', 'sink', 'skateboard', 'skis', 'snowboard',
    'spoon', 'sports ball', 'stop sign', 'suitcase', 'surfboard', 'teddy bear',
    'tennis racket', 'tie', 'toaster', 'toothbrush', 'traffic light', 'train',
    'truck', 'umbrella', 'vase', 'wine glass', 'zebra'
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera(); // Start camera initialization
    _initializeYolo(); // Load YOLO model
    _createPairing(); // Set up Firebase pairing
  }

  // Create a new pairing in Firebase with the pairing code
  // Create a new pairing and get monitor's FCM token
  Future<void> _createPairing() async {
    await _securityService.createPairing(widget.pairingCode, _selectedObjects);
    // Get ALL monitor tokens
    _monitorDevices = await _securityService.getAllMonitorTokens(widget.pairingCode);

    if (_monitorDevices.isNotEmpty) {
      debugPrint('Found ${_monitorDevices.length} monitor device(s) paired');
    }
    // Listen for new monitors joining
    _listenForMonitorChanges();
  }

  void _listenForMonitorChanges() {
    final monitorsRef = FirebaseDatabase.instance.ref('security-pairings/${widget.pairingCode}/devices/monitors');
    monitorsRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          setState(() {
            _monitorDevices = [];
            data.forEach((userId, monitorData) {
              if (monitorData is Map) {
                final monitor = Map<String, dynamic>.from(monitorData);
                monitor['userId'] = userId;
                _monitorDevices.add(monitor);
              }
            });
          });

          debugPrint('Monitors updated: ${_monitorDevices.length} device(s) connected');
        }
      } else {
        setState(() => _monitorDevices = []);
        debugPrint('No monitors connected');
      }
    });
  }
  // Initialize the device camera
  Future<void> _initializeCamera() async {
    try {
      // Get list of available cameras on the device
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Create camera controller with first available camera
        _cameraController = CameraController(
          cameras.first, // Use first camera (usually back camera)
          ResolutionPreset.high, // Use high resolution for better detection
        );
        // Initialize camera hardware
        await _cameraController!.initialize();
        // Start with flash off
        await _cameraController!.setFlashMode(FlashMode.off);
        // Update UI state when camera is ready
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _startDetection(); // Start the detection loop
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  // Initialize YOLO object detection model
  Future<void> _initializeYolo() async {
    try {
      await YoloDetector.initialize(); // Load model and labels
    } catch (e) {
      debugPrint('Error initializing YOLO: $e');
    }
  }

  // Toggle camera flash on/off
  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      // Determine new flash mode based on current state
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      setState(() {
        _isFlashOn = !_isFlashOn; // Toggle state
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flash not available on this device'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Start periodic object detection
  void _startDetection() {
    // Run detection every 2.5 seconds (2500 milliseconds)
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
          (timer) => _performDetection(), // Callback function
    );
  }

  // Clean up previously captured images to save storage
  void _cleanupLastImage() {
    if (_lastImagePath != null) {
      try {
        File(_lastImagePath!).deleteSync(); // Delete file synchronously
        _lastImagePath = null; // Clear reference
      } catch (e) {
        debugPrint('Error cleaning up image: $e');
      }
    }
  }

  // Main object detection function
  Future<void> _performDetection() async {
    // Prevent multiple simultaneous detections and check camera readiness
    if (_isDetecting || !mounted || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isDetecting = true; // Set detecting flag
    });

    try {
      _cleanupLastImage(); // Clean up previous image

      // Capture image from camera
      final image = await _cameraController!.takePicture();
      _lastImagePath = image.path; // Store path for cleanup
      final file = File(image.path);

      // Get image dimensions for proper scaling
      final imageBytes = await file.readAsBytes();
      final decodedImage = await decodeImageFromList(imageBytes);
      _previewSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

      // Run object detection on captured image
      final detections = await YoloDetector.detectObjects(file);

      // Check if any monitored object was detected
      bool monitoredObjectDetected = false;
      for (var detection in detections) {
        if (_selectedObjects.contains(detection.label)) {
          monitoredObjectDetected = true;
          // Send alert if detected object is being monitored
          await _sendAlert(detection.label, detection.confidence);
        }
      }

      // If a monitored object was detected, save the photo to gallery
      if (monitoredObjectDetected) {
        await _savePhotoToGallery(file);
      }

      // Clean up the temporary image file (always delete from temp location)
      await file.delete();
      _lastImagePath = null;

      // Update UI with new detections
      if (mounted) {
        setState(() {
          _detections = detections;
          _isDetecting = false;
        });
      }
    } catch (e) {
      debugPrint('Error in detection: $e');
      if (mounted) {
        setState(() {
          _isDetecting = false; // Reset detecting flag on error
        });
      }
      _cleanupLastImage(); // Ensure cleanup even on error
    }
  }


  // Save captured photo to device gallery
  Future<void> _savePhotoToGallery(File imageFile) async {
    try {
      debugPrint('Saving photo to gallery...');
      
      // Save image to gallery using PhotoManager
      await PhotoManager.editor.saveImageWithPath(
        imageFile.path,
        title: 'VisionGo_${DateTime.now().millisecondsSinceEpoch}',
      );

      debugPrint(' Photo saved to gallery successfully');
      
      // Show success feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Photo saved to gallery'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving photo to gallery: $e');
      
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Send security alert to Firebase and show local notification
  // Send security alert to Firebase and push notification to monitor
  Future<void> _sendAlert(String objectLabel, double confidence) async {
    // 1. Save alert to Firebase
    await _securityService.addAlert(widget.pairingCode, objectLabel, confidence);

    // 2. Show local notification on THIS device (camera)
    await _notificationService.sendSecurityAlert(
      object: objectLabel,
      confidence: confidence,
      pairingCode: widget.pairingCode,
    );

    // 3. Send push notification to ALL monitor devices
    if (_monitorDevices.isNotEmpty) {
      int successCount = 0;

      for (var monitor in _monitorDevices) {
        final fcmToken = monitor['fcmToken'] as String?;

        if (fcmToken != null) {
          final sent = await _fcmApiService.sendSecurityAlert(
            fcmToken: fcmToken,
            objectLabel: objectLabel,
            confidence: confidence,
            pairingCode: widget.pairingCode,
          );

          if (sent) successCount++;
        }
      }

      debugPrint('✅ Push notifications sent to $successCount/${_monitorDevices.length} monitors');
    } else {
      debugPrint('⚠️ No monitors paired yet - only local alert saved');
    }
    debugPrint('ALERT: Detected $objectLabel - Alert sent');

    // 4. Show visual feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _monitorDevices.isEmpty
                ? '⚠️ Alert: $objectLabel detected! (No monitors paired)'
                : '⚠️ Alert sent to ${_monitorDevices.length} monitor(s)',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Show bottom sheet for object selection
  void _showObjectSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A), // Dark theme
      isScrollControlled: true, // Allow full screen expansion
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ObjectSelectionSheet(
        allObjects: _allObjects,
        selectedObjects: _selectedObjects,
        onSelectionChanged: (newSelection) async {
          setState(() {
            _selectedObjects = newSelection; // Update local state
          });
          // Update Firebase with new selection
          await _securityService.updateSelectedObjects(
            widget.pairingCode,
            _selectedObjects,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel(); // Stop detection timer
    _cleanupLastImage(); // Clean up any remaining images
    _cameraController?.dispose(); // Release camera resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size; // Get screen dimensions

    return Scaffold(
      backgroundColor: Colors.black, // Black background for camera view
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview - Main background
            if (_isInitialized && _cameraController != null)
              Positioned.fill(
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover, // Cover entire screen while maintaining aspect ratio
                    child: SizedBox(
                      width: screenSize.width,
                      height: screenSize.width * _cameraController!.value.aspectRatio,
                      child: CameraPreview(_cameraController!), // Actual camera feed
                    ),
                  ),
                ),
              )
            else
            // Show loading indicator while camera initializes
              const Center(
                child: CircularProgressIndicator(color: Colors.tealAccent),
              ),

            // Bounding Boxes Overlay - Draw detection boxes on top of camera feed
            if (_detections.isNotEmpty && _previewSize != null && _isInitialized)
              Positioned.fill(
                child: CustomPaint(
                  painter: SecurityDetectionPainter(
                    _detections,
                    _previewSize!,
                    screenSize,
                    _cameraController!.value.aspectRatio,
                    _selectedObjects,
                  ),
                ),
              ),

            // Top Bar - Controls and information
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _circleButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.pop(context),
                  ),
                  // Pairing code display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7), // Semi-transparent background
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.security, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Code: ${widget.pairingCode}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Control buttons (flash and object selection)
                  Row(
                    children: [
                      _circleButton(
                        icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        onPressed: _toggleFlash,
                        color: _isFlashOn ? Colors.amber : null, // Amber when on
                      ),
                      const SizedBox(width: 8),
                      _circleButton(
                        icon: Icons.tune, // Settings/configuration icon
                        onPressed: _showObjectSelection,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Info - Status information
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8), // Dark at bottom
                      Colors.transparent, // Fade to transparent
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Monitoring status
                    if (_selectedObjects.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: Colors.tealAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Monitoring ${_selectedObjects.length} object${_selectedObjects.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Detection count
                    if (_detections.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${_detections.length} object${_detections.length == 1 ? '' : 's'} detected',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable circular button widget
  Widget _circleButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5), // Semi-transparent background
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white), // White by default, custom color if provided
        onPressed: onPressed,
      ),
    );
  }
}

/// Bottom sheet for selecting which objects to monitor.
///
/// Displays all 80 COCO class labels in a searchable, two-column grid
/// with checkboxes. Selection changes are immediately persisted to Firebase.
class _ObjectSelectionSheet extends StatefulWidget {
  final List<String> allObjects; // All available objects
  final List<String> selectedObjects; // Currently selected objects
  final Function(List<String>) onSelectionChanged; // Callback when selection changes

  const _ObjectSelectionSheet({
    required this.allObjects,
    required this.selectedObjects,
    required this.onSelectionChanged,
  });

  @override
  State<_ObjectSelectionSheet> createState() => _ObjectSelectionSheetState();
}

class _ObjectSelectionSheetState extends State<_ObjectSelectionSheet> {
  late List<String> _selectedObjects; // Local copy of selected objects
  String _searchQuery = ''; // Current search query
  final TextEditingController _searchController = TextEditingController(); // Search field controller

  @override
  void initState() {
    super.initState();
    // Initialize with current selection
    _selectedObjects = List.from(widget.selectedObjects);
  }

  @override
  void dispose() {
    _searchController.dispose(); // Clean up controller
    super.dispose();
  }

  // Get filtered list of objects based on search query
  List<String> _getFilteredObjects() {
    if (_searchQuery.isEmpty) {
      return widget.allObjects; // Return all objects if no search
    }

    // Filter objects that match search query (case insensitive)
    return widget.allObjects
        .where((obj) => obj.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList()
      ..sort(); // Sort alphabetically when searching
  }

  // Toggle selection of an object
  void _toggleSelection(String object) {
    setState(() {
      if (_selectedObjects.contains(object)) {
        _selectedObjects.remove(object); // Deselect if already selected
      } else {
        _selectedObjects.add(object); // Select if not selected
      }
    });
    // Notify parent of selection change
    widget.onSelectionChanged(_selectedObjects);
  }

  @override
  Widget build(BuildContext context) {
    final filteredObjects = _getFilteredObjects();

    return DraggableScrollableSheet(
      initialChildSize: 0.8, // Start at 80% of screen height
      maxChildSize: 0.95, // Can expand to 95% of screen height
      minChildSize: 0.5, // Can collapse to 50% of screen height
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle indicator
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Select Objects to Monitor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // Selection count
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${_selectedObjects.length} object${_selectedObjects.length == 1 ? '' : 's'} selected',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search objects...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = ''; // Clear search
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A), // Dark background
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none, // No border
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value; // Update search query
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Grid of selectable objects
            Expanded(
              child: GridView.builder(
                controller: scrollController, // For scrollable content
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Two columns
                  childAspectRatio: 3, // Width:Height ratio
                  crossAxisSpacing: 8, // Space between columns
                  mainAxisSpacing: 8, // Space between rows
                ),
                itemCount: filteredObjects.length,
                itemBuilder: (context, index) {
                  final object = filteredObjects[index];
                  final isSelected = _selectedObjects.contains(object);

                  return GestureDetector(
                    onTap: () => _toggleSelection(object),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.tealAccent.withValues(alpha: 0.15) // Selected color
                            : const Color(0xFF2A2A2A), // Unselected color
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.tealAccent // Border for selected items
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(object),
                            activeColor: Colors.tealAccent,
                            checkColor: Colors.black, // Dark checkmark for contrast
                          ),
                          Expanded(
                            child: Text(
                              object,
                              style: TextStyle(
                                color: isSelected ? Colors.tealAccent : Colors.white,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis, // Truncate long names
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Confirm button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Selection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter for drawing detection bounding boxes on the camera feed.
///
/// Monitored objects are drawn in red; other detections cycle through
/// a colour palette. Coordinates are scaled from the original image size
/// to the screen size with aspect-ratio correction.
class SecurityDetectionPainter extends CustomPainter {
  final List<Detection> detections; // Detection results to draw
  final Size previewSize; // Original image size from camera
  final Size screenSize; // Screen size for scaling
  final double cameraAspectRatio; // Camera aspect ratio
  final List<String> monitoredObjects; // Objects being monitored for alerts

  SecurityDetectionPainter(
      this.detections,
      this.previewSize,
      this.screenSize,
      this.cameraAspectRatio,
      this.monitoredObjects,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke // Draw outlines only
      ..strokeWidth = 3; // Line thickness

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Calculate aspect ratios for proper scaling
    final previewAspectRatio = previewSize.width / previewSize.height;
    final screenAspectRatio = screenSize.width / screenSize.height;

    double scaleX;
    double scaleY;
    double offsetX = 0;
    double offsetY = 0;

    // Calculate scaling factors to maintain aspect ratio
    if (screenAspectRatio > previewAspectRatio) {
      // Screen is wider than camera preview - scale by width
      scaleX = screenSize.width / previewSize.width;
      scaleY = scaleX; // Maintain aspect ratio
      offsetY = (screenSize.height - (previewSize.height * scaleY)) / 2; // Center vertically
    } else {
      // Screen is taller than camera preview - scale by height
      scaleY = screenSize.height / previewSize.height;
      scaleX = scaleY; // Maintain aspect ratio
      offsetX = (screenSize.width - (previewSize.width * scaleX)) / 2; // Center horizontally
    }

    // Draw each detection
    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      // Use red for monitored objects, different colors for others
      final isMonitored = monitoredObjects.contains(detection.label);
      final color = isMonitored ? Colors.red : _getColorForIndex(i);

      paint.color = color;

      // Convert detection coordinates to screen coordinates
      final rect = Rect.fromLTRB(
        (detection.boundingBox.x1 * scaleX) + offsetX,
        (detection.boundingBox.y1 * scaleY) + offsetY,
        (detection.boundingBox.x2 * scaleX) + offsetX,
        (detection.boundingBox.y2 * scaleY) + offsetY,
      );

      // Draw bounding box
      canvas.drawRect(rect, paint);

      // Prepare label text with object name and confidence
      final labelText = '${detection.label} ${(detection.confidence * 100).toInt()}%';
      textPainter.text = TextSpan(
        text: labelText,
        style: TextStyle(
          color: color, // Use same color as bounding box
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout(); // Calculate text dimensions

      // Draw background for label text
      final labelBackgroundRect = Rect.fromLTWH(
        rect.left,
        rect.top - 20, // Position above bounding box
        textPainter.width + 8, // Add padding
        20, // Fixed height
      );

      canvas.drawRect(
        labelBackgroundRect,
        Paint()..color = Colors.black.withValues(alpha: 0.7), // Semi-transparent background
      );

      // Draw the text
      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 18));
    }
  }

  // Get consistent colors for different detection indices
  Color _getColorForIndex(int index) {
    final colors = [
      Colors.pink,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.yellow,
      Colors.cyan,
      Colors.lime,
    ];
    return colors[index % colors.length]; // Cycle through colors
  }

  @override
  bool shouldRepaint(SecurityDetectionPainter oldDelegate) => true;
// Always repaint when new detections are available
}
