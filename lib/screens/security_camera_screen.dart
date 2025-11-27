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

  final List<String> _allObjects = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
    'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat',
    'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
    'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
    'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
    'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair',
    'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
    'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'book',
    'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
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

      // Get actual image dimensions
      final imageBytes = await file.readAsBytes();
      final decodedImage = await decodeImageFromList(imageBytes);
      _previewSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

      final detections = await YoloDetector.detectObjects(file);

      // Check for selected objects and send alerts
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
    // Save alert to Firebase security service
    await _securityService.addAlert(widget.pairingCode, objectLabel, confidence);

    debugPrint('ALERT: Detected $objectLabel - Saved to security service');

    // Show local notification
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
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
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _allObjects.length,
                      itemBuilder: (context, index) {
                        final object = _allObjects[index];
                        final isSelected = _selectedObjects.contains(object);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.tealAccent.withOpacity(0.1)
                                : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.tealAccent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) async {
                              setModalState(() {
                                if (value == true) {
                                  _selectedObjects.add(object);
                                } else {
                                  _selectedObjects.remove(object);
                                }
                              });
                              setState(() {});
                              // Update in security service
                              await _securityService.updateSelectedObjects(
                                widget.pairingCode,
                                _selectedObjects,
                              );
                            },
                            title: Text(
                              object,
                              style: TextStyle(
                                color: isSelected ? Colors.tealAccent : Colors.white,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            activeColor: Colors.tealAccent,
                            checkColor: Colors.black,
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
                      color: Colors.black.withOpacity(0.7),
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
                      Colors.black.withOpacity(0.8),
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
                          color: Colors.tealAccent.withOpacity(0.2),
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
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white),
        onPressed: onPressed,
      ),
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

    // Calculate scaling for the full-screen camera preview
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

      // Scale bounding box to screen coordinates
      final rect = Rect.fromLTRB(
        (detection.boundingBox.x1 * scaleX) + offsetX,
        (detection.boundingBox.y1 * scaleY) + offsetY,
        (detection.boundingBox.x2 * scaleX) + offsetX,
        (detection.boundingBox.y2 * scaleY) + offsetY,
      );

      // Draw bounding box
      canvas.drawRect(rect, paint);

      // Draw label background
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
        Paint()..color = Colors.black.withOpacity(0.7),
      );

      // Draw label text
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
