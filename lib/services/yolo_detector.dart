import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';

class YoloDetector {
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _isInitialized = false;

  static const int inputSize = 640;
  static const double confidenceThreshold = 0.25;
  static const double iouThreshold = 0.45;
  static const int numClasses = 80;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/yolov8n_float32.tflite');

      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing YOLO detector: $e');
      throw Exception('Failed to initialize YOLO detector: $e');
    }
  }

  static Future<List<Detection>> detectFromCameraImage(CameraImage cameraImage) async {
    if (!_isInitialized) await initialize();

    try {
      final image = _convertCameraImage(cameraImage);
      if (image == null) return [];

      final preprocessedImage = _preprocessImage(image);
      final output = _runInference(preprocessedImage);
      return _postProcessOutput(output, image.width, image.height);
    } catch (e) {
      debugPrint('Error in live detection: $e');
      return [];
    }
  }

  static Future<List<Detection>> detectObjects(File imageFile) async {
    if (!_isInitialized) await initialize();

    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) throw Exception('Failed to decode image');

      final preprocessedImage = _preprocessImage(image);
      final output = _runInference(preprocessedImage);
      return _postProcessOutput(output, image.width, image.height);
    } catch (e) {
      debugPrint('Error in object detection: $e');
      rethrow;
    }
  }

  static img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.jpeg) {
        return _convertJPEGToImage(cameraImage);
      }
      return null;
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  static img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;
    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final index = y * width + x;

        final yp = cameraImage.planes[0].bytes[index];
        final up = cameraImage.planes[1].bytes[uvIndex];
        final vp = cameraImage.planes[2].bytes[uvIndex];

        final r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        final g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        final b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return image;
  }

  static img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );
  }

  static img.Image? _convertJPEGToImage(CameraImage cameraImage) {
    return img.decodeJpg(cameraImage.planes[0].bytes);
  }

  static List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    return List.generate(
      1,
          (_) => List.generate(
        inputSize,
            (y) => List.generate(
          inputSize,
              (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          },
        ),
      ),
    );
  }

  static List<List<double>> _runInference(List<List<List<List<double>>>> input) {
    final output = List.generate(1, (_) => List.generate(84, (_) => List.filled(8400, 0.0)));

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      debugPrint('Error during inference: $e');
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

    for (int i = 0; i < 8400; i++) {
      final x = output[0][i];
      final y = output[1][i];
      final w = output[2][i];
      final h = output[3][i];

      double maxScore = 0;
      int maxIndex = 0;
      for (int j = 4; j < 84; j++) {
        final score = output[j][i];
        if (score > maxScore) {
          maxScore = score;
          maxIndex = j - 4;
        }
      }

      if (maxScore > confidenceThreshold) {
        final scaleX = originalWidth / inputSize;
        final scaleY = originalHeight / inputSize;

        final x1 = ((x - w / 2) * scaleX).clamp(0.0, originalWidth.toDouble());
        final y1 = ((y - h / 2) * scaleY).clamp(0.0, originalHeight.toDouble());
        final x2 = ((x + w / 2) * scaleX).clamp(0.0, originalWidth.toDouble());
        final y2 = ((y + h / 2) * scaleY).clamp(0.0, originalHeight.toDouble());

        if (x2 > x1 && y2 > y1) {
          detections.add(Detection(
            label: _labels != null && maxIndex < _labels!.length ? _labels![maxIndex] : 'Class $maxIndex',
            confidence: maxScore,
            boundingBox: BoundingBox(x1: x1, y1: y1, x2: x2, y2: y2),
          ));
        }
      }
    }

    return _nonMaxSuppression(detections);
  }

  static List<Detection> _nonMaxSuppression(List<Detection> detections) {
    if (detections.isEmpty) return [];

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selected = <Detection>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;

      selected.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j] || detections[i].label != detections[j].label) continue;

        if (_calculateIoU(detections[i].boundingBox, detections[j].boundingBox) > iouThreshold) {
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

  Detection({required this.label, required this.confidence, required this.boundingBox});

  @override
  String toString() {
    return 'Detection(label: $label, confidence: ${(confidence * 100).toStringAsFixed(1)}%, bbox: $boundingBox)';
  }
}

class BoundingBox {
  final double x1, y1, x2, y2;

  BoundingBox({required this.x1, required this.y1, required this.x2, required this.y2});

  double get width => x2 - x1;
  double get height => y2 - y1;
  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;

  @override
  String toString() {
    return 'BoundingBox(x1: ${x1.toStringAsFixed(1)}, y1: ${y1.toStringAsFixed(1)}, x2: ${x2.toStringAsFixed(1)}, y2: ${y2.toStringAsFixed(1)})';
  }
}