import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import '../services/yolo_detector.dart';

class LiveDetectionScreen extends StatefulWidget {
  final CameraController camera;

  const LiveDetectionScreen({
    super.key,
    required this.camera,
  });

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  bool _isDetecting = false;
  List<Detection> _detections = [];
  Timer? _detectionTimer;
  bool _isInitialized = false;
  bool _isFlashOn = false;
  Size? _previewSize;
  String? _lastImagePath;
  int _skippedFrames = 0;

  @override
  void initState() {
    super.initState();
    _initializeYolo();
  }

  Future<void> _initializeYolo() async {
    try {
      // Ensure flash is off on start
      await widget.camera.setFlashMode(FlashMode.off);

      await YoloDetector.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startLiveDetection();
      }
    } catch (e) {
      debugPrint('Error initializing YOLO: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing YOLO: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cleanupLastImage();
    super.dispose();
  }

  void _cleanupLastImage() {
    if (_lastImagePath != null) {
      try {
        File(_lastImagePath!).deleteSync();
      } catch (e) {
        debugPrint('Error cleaning up image: $e');
      }
      _lastImagePath = null;
    }
  }

  void _startLiveDetection() {
    // Increased to 2.5 seconds for smoother performance
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
          (timer) => _performLiveDetection(),
    );
  }

  Future<void> _performLiveDetection() async {
    // Skip if already detecting or camera not ready
    if (_isDetecting || !mounted || !_isInitialized || !widget.camera.value.isInitialized) {
      _skippedFrames++;
      if (_skippedFrames > 5) {
        // Clear detections if we've skipped too many frames
        if (mounted) {
          setState(() {
            _detections = [];
          });
        }
        _skippedFrames = 0;
      }
      return;
    }

    _skippedFrames = 0;
    setState(() {
      _isDetecting = true;
    });

    try {
      // Clean up previous image
      _cleanupLastImage();

      // Ensure flash is off before taking picture (unless user turned it on)
      await widget.camera.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);

      // Capture image
      final image = await widget.camera.takePicture();
      _lastImagePath = image.path;
      final file = File(image.path);

      // Get the actual image dimensions
      final imageFile = await file.readAsBytes();
      final decodedImage = await decodeImageFromList(imageFile);

      // Store the actual captured image size
      _previewSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

      debugPrint('Image size: ${_previewSize?.width} x ${_previewSize?.height}');
      debugPrint('Camera preview size: ${widget.camera.value.previewSize}');

      // Run detection
      final detections = await YoloDetector.detectObjects(file);

      // Clean up immediately after detection
      await file.delete();
      _lastImagePath = null;

      if (mounted) {
        setState(() {
          _detections = detections;
          _isDetecting = false;
        });
      }
    } catch (e) {
      debugPrint('Error in live detection: $e');
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
      _cleanupLastImage();
    }
  }

  Future<void> _toggleFlash() async {
    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await widget.camera.setFlashMode(newFlashMode);
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

  void _captureFrame() async {
    try {
      final image = await widget.camera.takePicture();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Frame captured: ${image.path.split('/').last}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing frame: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error capturing frame'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview - Fill entire screen
            Positioned.fill(
              child: widget.camera.value.isInitialized
                  ? OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: screenSize.width,
                    height: screenSize.width * widget.camera.value.aspectRatio,
                    child: CameraPreview(widget.camera),
                  ),
                ),
              )
                  : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

            // Bounding Boxes Overlay
            if (_detections.isNotEmpty && _previewSize != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: LiveDetectionPainter(
                    _detections,
                    _previewSize!,
                    screenSize,
                    widget.camera.value.aspectRatio,
                  ),
                ),
              ),

            // Loading Overlay
            if (!_isInitialized)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Initializing YOLO...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isInitialized ? Colors.red : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isInitialized ? 'LIVE YOLO' : 'LOADING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Info Panel
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
                    if (_isDetecting) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Detecting...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_detections.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_detections.length} object${_detections.length == 1 ? '' : 's'} detected',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _detections.take(5).map((detection) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.pink.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${detection.label} ${(detection.confidence * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ] else if (_isInitialized) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'No objects detected',
                          style: TextStyle(color: Colors.white70),
                        ),
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

class LiveDetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size previewSize;
  final Size screenSize;
  final double cameraAspectRatio;

  LiveDetectionPainter(
      this.detections,
      this.previewSize,
      this.screenSize,
      this.cameraAspectRatio,
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

    // Since we're using BoxFit.cover, calculate the scale accordingly
    if (screenAspectRatio > previewAspectRatio) {
      // Screen is wider - scale to width
      scaleX = screenSize.width / previewSize.width;
      scaleY = scaleX;
      offsetY = (screenSize.height - (previewSize.height * scaleY)) / 2;
    } else {
      // Screen is taller - scale to height
      scaleY = screenSize.height / previewSize.height;
      scaleX = scaleY;
      offsetX = (screenSize.width - (previewSize.width * scaleX)) / 2;
    }

    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final color = _getColorForIndex(i);

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

      // Draw label
      final labelText = '${detection.label} ${(detection.confidence * 100).toInt()}%';
      textPainter.text = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      final labelY = rect.top > 24 ? rect.top - 24 : rect.top + 4;

      // Draw label background
      final labelRect = Rect.fromLTWH(
        rect.left,
        labelY,
        textPainter.width + 8,
        20,
      );
      canvas.drawRect(labelRect, Paint()..color = color);

      // Draw label text
      textPainter.paint(canvas, Offset(rect.left + 4, labelY + 2));
    }
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}