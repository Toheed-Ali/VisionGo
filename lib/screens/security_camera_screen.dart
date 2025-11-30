import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import '../services/yolo_detector.dart';
import '../services/firebase_security_service.dart';

class SecurityCameraScreen extends StatefulWidget {
  final String pairingCode;

  const SecurityCameraScreen({
    super.key,
    required this.pairingCode,
  });

  @override
  State<SecurityCameraScreen> createState() => _SecurityCameraScreenState();
}

class _SecurityCameraScreenState extends State<SecurityCameraScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isFlashOn = false;
  List<Detection> _detections = [];
  Timer? _detectionTimer;
  List<String> _selectedObjects = [];
  Size? _previewSize;
  String? _lastImagePath;

  final FirebaseSecurityService _securityService = FirebaseSecurityService();

  // Priority objects are now at the beginning of the main list
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
    _initializeCamera();
    _initializeYolo();
    _createPairing();
  }

  Future<void> _createPairing() async {
    await _securityService.createPairing(widget.pairingCode, _selectedObjects);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
        );
        await _cameraController!.initialize();
        await _cameraController!.setFlashMode(FlashMode.off);
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _startDetection();
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _initializeYolo() async {
    try {
      await YoloDetector.initialize();
    } catch (e) {
      debugPrint('Error initializing YOLO: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
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

  void _startDetection() {
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
          (timer) => _performDetection(),
    );
  }

  void _cleanupLastImage() {
    if (_lastImagePath != null) {
      try {
        File(_lastImagePath!).deleteSync();
        _lastImagePath = null;
      } catch (e) {
        debugPrint('Error cleaning up image: $e');
      }
    }
  }

  Future<void> _performDetection() async {
    if (_isDetecting || !mounted || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isDetecting = true;
    });

    try {
      _cleanupLastImage();

      final image = await _cameraController!.takePicture();
      _lastImagePath = image.path;
      final file = File(image.path);

      final imageBytes = await file.readAsBytes();
      final decodedImage = await decodeImageFromList(imageBytes);
      _previewSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

      final detections = await YoloDetector.detectObjects(file);

      for (var detection in detections) {
        if (_selectedObjects.contains(detection.label)) {
          await _sendAlert(detection.label, detection.confidence);
        }
      }

      await file.delete();
      _lastImagePath = null;

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
          _isDetecting = false;
        });
      }
      _cleanupLastImage();
    }
  }

  Future<void> _sendAlert(String objectLabel, double confidence) async {
    await _securityService.addAlert(widget.pairingCode, objectLabel, confidence);

    debugPrint('ALERT: Detected $objectLabel - Saved to security service');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Alert: $objectLabel detected!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showObjectSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ObjectSelectionSheet(
        allObjects: _allObjects,
        selectedObjects: _selectedObjects,
        onSelectionChanged: (newSelection) async {
          setState(() {
            _selectedObjects = newSelection;
          });
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
    _detectionTimer?.cancel();
    _cleanupLastImage();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            if (_isInitialized && _cameraController != null)
              Positioned.fill(
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: screenSize.width,
                      height: screenSize.width * _cameraController!.value.aspectRatio,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.tealAccent),
              ),

            // Bounding Boxes Overlay
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

            // Top Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
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
                  Row(
                    children: [
                      _circleButton(
                        icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        onPressed: _toggleFlash,
                        color: _isFlashOn ? Colors.amber : null,
                      ),
                      const SizedBox(width: 8),
                      _circleButton(
                        icon: Icons.tune,
                        onPressed: _showObjectSelection,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Info
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
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

// Separate stateful widget for object selection
class _ObjectSelectionSheet extends StatefulWidget {
  final List<String> allObjects;
  final List<String> selectedObjects;
  final Function(List<String>) onSelectionChanged;

  const _ObjectSelectionSheet({
    required this.allObjects,
    required this.selectedObjects,
    required this.onSelectionChanged,
  });

  @override
  State<_ObjectSelectionSheet> createState() => _ObjectSelectionSheetState();
}

class _ObjectSelectionSheetState extends State<_ObjectSelectionSheet> {
  late List<String> _selectedObjects;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedObjects = List.from(widget.selectedObjects);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getFilteredObjects() {
    if (_searchQuery.isEmpty) {
      // Return objects in their original order (priority first, then others)
      return widget.allObjects;
    }

    // When searching, return filtered results sorted alphabetically
    return widget.allObjects
        .where((obj) => obj.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList()
      ..sort();
  }

  void _toggleSelection(String object) {
    setState(() {
      if (_selectedObjects.contains(object)) {
        _selectedObjects.remove(object);
      } else {
        _selectedObjects.add(object);
      }
    });
    // Update Firebase asynchronously without waiting
    widget.onSelectionChanged(_selectedObjects);
  }

  @override
  Widget build(BuildContext context) {
    final filteredObjects = _getFilteredObjects();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
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
                        _searchQuery = '';
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Grid of objects
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
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
                            ? Colors.tealAccent.withValues(alpha: 0.15)
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.tealAccent
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
                            checkColor: Colors.black,
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
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

// Custom painter for drawing bounding boxes
class SecurityDetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size previewSize;
  final Size screenSize;
  final double cameraAspectRatio;
  final List<String> monitoredObjects;

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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final previewAspectRatio = previewSize.width / previewSize.height;
    final screenAspectRatio = screenSize.width / screenSize.height;

    double scaleX;
    double scaleY;
    double offsetX = 0;
    double offsetY = 0;

    if (screenAspectRatio > previewAspectRatio) {
      scaleX = screenSize.width / previewSize.width;
      scaleY = scaleX;
      offsetY = (screenSize.height - (previewSize.height * scaleY)) / 2;
    } else {
      scaleY = screenSize.height / previewSize.height;
      scaleX = scaleY;
      offsetX = (screenSize.width - (previewSize.width * scaleX)) / 2;
    }

    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final isMonitored = monitoredObjects.contains(detection.label);
      final color = isMonitored ? Colors.red : _getColorForIndex(i);

      paint.color = color;

      final rect = Rect.fromLTRB(
        (detection.boundingBox.x1 * scaleX) + offsetX,
        (detection.boundingBox.y1 * scaleY) + offsetY,
        (detection.boundingBox.x2 * scaleX) + offsetX,
        (detection.boundingBox.y2 * scaleY) + offsetY,
      );

      canvas.drawRect(rect, paint);

      final labelText = '${detection.label} ${(detection.confidence * 100).toInt()}%';
      textPainter.text = TextSpan(
        text: labelText,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      final labelBackgroundRect = Rect.fromLTWH(
        rect.left,
        rect.top - 20,
        textPainter.width + 8,
        20,
      );

      canvas.drawRect(
        labelBackgroundRect,
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      );

      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 18));
    }
  }

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
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(SecurityDetectionPainter oldDelegate) => true;
}