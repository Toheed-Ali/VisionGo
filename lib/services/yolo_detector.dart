import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class YoloDetector {
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _isInitialized = false;

  // YOLO model configuration
  static const int inputSize = 640;
  static const double confidenceThreshold = 0.25; // Lowered for better detection
  static const double iouThreshold = 0.45;
  static const int numClasses = 80; // COCO dataset has 80 classes

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load YOLO model
      _interpreter = await Interpreter.fromAsset('assets/models/yolov8n_float32.tflite');

      // Print model input/output shapes for debugging
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');

      // Load labels
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      print('Loaded ${_labels?.length ?? 0} labels');

      _isInitialized = true;
      print('YOLO Detector initialized successfully');
    } catch (e) {
      print('Error initializing YOLO detector: $e');
      throw Exception('Failed to initialize YOLO detector: $e');
    }
  }

  static Future<List<Detection>> detectObjects(File imageFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Read and decode image
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      print('Original image size: ${image.width}x${image.height}');

      // Preprocess image
      final preprocessedImage = _preprocessImage(image);

      // Run inference
      final output = _runInference(preprocessedImage);

      // Post-process results
      final detections = _postProcessOutput(output, image.width, image.height);

      print('Detected ${detections.length} objects');

      return detections;
    } catch (e) {
      print('Error in object detection: $e');
      rethrow;
    }
  }

  static List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Resize image to input size maintaining aspect ratio
    final resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Create input tensor with shape [1, 640, 640, 3]
    // Normalize to [0, 1] range
    final input = List.generate(
      1, // batch
          (_) => List.generate(
        inputSize, // height
            (y) => List.generate(
          inputSize, // width
              (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  static List<List<double>> _runInference(List<List<List<List<double>>>> input) {
    // YOLOv8 output shape is [1, 84, 8400]
    // Where 84 = 4 (bbox coords) + 80 (class scores)
    final output = List.generate(
      1,
          (_) => List.generate(
        84,
            (_) => List.filled(8400, 0.0),
      ),
    );

    try {
      _interpreter!.run(input, output);
      print('Inference completed successfully');
    } catch (e) {
      print('Error during inference: $e');
      rethrow;
    }

    return output[0];
  }

  static List<Detection> _postProcessOutput(
      List<List<double>> output,
      int originalWidth,
      int originalHeight,
      ) {
    final detections = <Detection>[];

    // YOLOv8 output format: [84, 8400]
    // First 4 rows are bbox coordinates (x, y, w, h)
    // Remaining 80 rows are class scores

    for (int i = 0; i < 8400; i++) {
      // Extract bounding box coordinates (normalized to input size)
      final x = output[0][i];
      final y = output[1][i];
      final w = output[2][i];
      final h = output[3][i];

      // Extract class scores
      double maxScore = 0;
      int maxIndex = 0;
      for (int j = 4; j < 84; j++) {
        final score = output[j][i];
        if (score > maxScore) {
          maxScore = score;
          maxIndex = j - 4; // Subtract 4 to get class index (0-79)
        }
      }

      // Filter by confidence threshold
      if (maxScore > confidenceThreshold) {
        // Convert from normalized coordinates to pixel coordinates
        // YOLOv8 uses center format: (x_center, y_center, width, height)
        final scaleX = originalWidth / inputSize;
        final scaleY = originalHeight / inputSize;

        final x1 = (x - w / 2) * scaleX;
        final y1 = (y - h / 2) * scaleY;
        final x2 = (x + w / 2) * scaleX;
        final y2 = (y + h / 2) * scaleY;

        // Ensure coordinates are within image bounds
        final clampedX1 = x1.clamp(0.0, originalWidth.toDouble());
        final clampedY1 = y1.clamp(0.0, originalHeight.toDouble());
        final clampedX2 = x2.clamp(0.0, originalWidth.toDouble());
        final clampedY2 = y2.clamp(0.0, originalHeight.toDouble());

        // Only add detection if bounding box is valid
        if (clampedX2 > clampedX1 && clampedY2 > clampedY1) {
          detections.add(Detection(
            label: _labels != null && maxIndex < _labels!.length
                ? _labels![maxIndex]
                : 'Class $maxIndex',
            confidence: maxScore,
            boundingBox: BoundingBox(
              x1: clampedX1,
              y1: clampedY1,
              x2: clampedX2,
              y2: clampedY2,
            ),
          ));
        }
      }
    }

    print('Found ${detections.length} detections before NMS');

    // Apply Non-Maximum Suppression
    final finalDetections = _nonMaxSuppression(detections);
    print('${finalDetections.length} detections after NMS');

    return finalDetections;
  }

  static List<Detection> _nonMaxSuppression(List<Detection> detections) {
    if (detections.isEmpty) return [];

    // Sort by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selected = <Detection>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;

      selected.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;

        // Only suppress boxes of the same class
        if (detections[i].label != detections[j].label) continue;

        final iou = _calculateIoU(
          detections[i].boundingBox,
          detections[j].boundingBox,
        );

        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return selected;
  }

  static double _calculateIoU(BoundingBox box1, BoundingBox box2) {
    final x1 = box1.x1 > box2.x1 ? box1.x1 : box2.x1;
    final y1 = box1.y1 > box2.y1 ? box1.y1 : box2.y1;
    final x2 = box1.x2 < box2.x2 ? box1.x2 : box2.x2;
    final y2 = box1.y2 < box2.y2 ? box1.y2 : box2.y2;

    if (x2 <= x1 || y2 <= y1) return 0.0;

    final intersectionArea = (x2 - x1) * (y2 - y1);
    final box1Area = (box1.x2 - box1.x1) * (box1.y2 - box1.y1);
    final box2Area = (box2.x2 - box2.x1) * (box2.y2 - box2.y1);
    final unionArea = box1Area + box2Area - intersectionArea;

    return intersectionArea / unionArea;
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
    _isInitialized = false;
  }
}

class Detection {
  final String label;
  final double confidence;
  final BoundingBox boundingBox;

  Detection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  @override
  String toString() {
    return 'Detection(label: $label, confidence: ${(confidence * 100).toStringAsFixed(1)}%, bbox: ${boundingBox.toString()})';
  }
}

class BoundingBox {
  final double x1, y1, x2, y2;

  BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  double get width => x2 - x1;
  double get height => y2 - y1;
  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;

  @override
  String toString() {
    return 'BoundingBox(x1: ${x1.toStringAsFixed(1)}, y1: ${y1.toStringAsFixed(1)}, x2: ${x2.toStringAsFixed(1)}, y2: ${y2.toStringAsFixed(1)})';
  }
}