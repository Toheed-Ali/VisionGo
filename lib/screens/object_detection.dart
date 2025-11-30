import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/yolo_detector.dart';

class ObjectDetectionScreen extends StatefulWidget {
  final AssetEntity asset;

  const ObjectDetectionScreen({
    super.key,
    required this.asset,
  });

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  Uint8List? _imageData;
  bool _isProcessing = false;
  List<Detection> _detections = [];
  String? _errorMessage;
  Size? _imageSize;
  bool _isImageLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load image first, then process after a delay
    _loadImageOnly();
  }

  Future<void> _loadImageOnly() async {
    try {
      final file = await widget.asset.file;
      if (file != null) {
        final bytes = await file.readAsBytes();

        // Get actual image dimensions
        final decodedImage = await decodeImageFromList(bytes);
        _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

        if (mounted) {
          setState(() {
            _imageData = bytes;
            _isImageLoaded = true;
          });

          // Wait for UI to render, then start detection
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _performObjectDetection(file);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading image: $e';
          _isImageLoaded = true;
        });
      }
    }
  }

  Future<void> _performObjectDetection(File file) async {
    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Initialize YOLO if not already done
      await YoloDetector.initialize();

      final detections = await YoloDetector.detectObjects(file);

      if (mounted) {
        setState(() {
          _detections = detections;
          if (detections.isEmpty) {
            _errorMessage = "No objects detected";
          }
        });
      }
    } catch (e) {
      debugPrint('Error in object detection: $e');
      if (mounted) {
        setState(() {
          _errorMessage = "Error: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _retryDetection() async {
    final file = await widget.asset.file;
    if (file != null) {
      _performObjectDetection(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'YOLO Detection',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isImageLoaded && !_isProcessing)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _retryDetection,
              tooltip: 'Retry Detection',
            ),
        ],
      ),
      body: !_isImageLoaded
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading image...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[900],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _imageData != null
                    ? LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'image_${widget.asset.id}',
                          child: Image.memory(
                            _imageData!,
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (_detections.isNotEmpty && !_isProcessing && _imageSize != null)
                          CustomPaint(
                            painter: DetectionPainter(
                              _detections,
                              _imageSize!,
                              constraints.biggest,
                            ),
                          ),
                        if (_isProcessing)
                          Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 16),
                                  Text(
                                    'Detecting objects...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
                    : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: _buildBottomSheet(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.pink),
            SizedBox(height: 16),
            Text(
              "Processing with YOLO...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retryDetection,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_detections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.pink),
            SizedBox(height: 16),
            Text(
              "Initializing...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detected Objects',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_detections.length} found',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.pink,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _detections.length,
            itemBuilder: (context, index) {
              final detection = _detections[index];
              final color = _getColorForIndex(index);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.label,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detection.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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
}

// Custom painter that draws bounding boxes and labels on the image
class DetectionPainter extends CustomPainter {
  final List<Detection> detections; // Detection results to draw
  final Size imageSize; // Original image dimensions
  final Size containerSize; // Display container dimensions

  DetectionPainter(this.detections, this.imageSize, this.containerSize);

  @override
  void paint(Canvas canvas, Size size) {
    // Setup paint for drawing bounding boxes
    final paint = Paint()
      ..style = PaintingStyle.stroke // Draw outlines only
      ..strokeWidth = 3; // Thick lines for visibility

    // Text painter for drawing labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr, // Left-to-right text
    );

    // Calculate aspect ratios for proper scaling
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    // Variables for scaled display calculations
    double displayWidth, displayHeight, offsetX, offsetY;

    // Calculate how to fit the image in the container while maintaining aspect ratio
    if (containerAspectRatio > imageAspectRatio) {
      // Container is wider than image - fit by height
      displayHeight = containerSize.height;
      displayWidth = displayHeight * imageAspectRatio;
      offsetX = (containerSize.width - displayWidth) / 2; // Center horizontally
      offsetY = 0;
    } else {
      // Container is taller than image - fit by width
      displayWidth = containerSize.width;
      displayHeight = displayWidth / imageAspectRatio;
      offsetX = 0;
      offsetY = (containerSize.height - displayHeight) / 2; // Center vertically
    }

    // Calculate scaling factors to convert from image coordinates to display coordinates
    final scaleX = displayWidth / imageSize.width;
    final scaleY = displayHeight / imageSize.height;

    // Draw each detection
    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final color = _getColorForIndex(i); // Get color for this detection

      paint.color = color; // Set bounding box color

      // Convert bounding box coordinates from image space to display space
      final scaledX1 = detection.boundingBox.x1 * scaleX + offsetX;
      final scaledY1 = detection.boundingBox.y1 * scaleY + offsetY;
      final scaledX2 = detection.boundingBox.x2 * scaleX + offsetX;
      final scaledY2 = detection.boundingBox.y2 * scaleY + offsetY;

      // Create rectangle for bounding box
      final rect = Rect.fromLTRB(scaledX1, scaledY1, scaledX2, scaledY2);

      // Draw the bounding box
      canvas.drawRect(rect, paint);

      // Prepare label text with object name and confidence
      final labelText = '${detection.label} ${(detection.confidence * 100).toInt()}%';
      textPainter.text = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white, // White text for contrast
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout(); // Calculate text dimensions

      // Position label above bounding box, or below if too close to top
      final labelY = scaledY1 > 24 ? scaledY1 - 24 : scaledY1 + 4;

      // Draw background rectangle for label text
      final labelBgRect = Rect.fromLTWH(
        scaledX1,
        labelY,
        textPainter.width + 8, // Add padding
        20, // Fixed height
      );
      canvas.drawRect(labelBgRect, Paint()..color = color);

      // Draw the text on top of the background
      textPainter.paint(canvas, Offset(scaledX1 + 4, labelY + 2));
    }
  }

  // Get consistent colors for detection boxes (same as in main class)
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
// Always repaint when new detections come in
// This could be optimized to only repaint when detections actually change
}