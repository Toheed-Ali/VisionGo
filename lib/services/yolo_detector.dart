// Import necessary Dart and Flutter libraries
import 'dart:io'; // For file operations
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/services.dart'; // For rootBundle to load assets
import 'package:tflite_flutter/tflite_flutter.dart'; // TensorFlow Lite Flutter plugin
import 'package:image/image.dart' as img; // Image processing library
import 'package:camera/camera.dart'; // Camera functionality

// Main class for YOLO (You Only Look Once) object detection
class YoloDetector {
  // TensorFlow Lite interpreter for running the model
  static Interpreter? _interpreter;
  // List of class labels (coco dataset labels like 'person', 'car', etc.)
  static List<String>? _labels;
  // Flag to track if the model is loaded and ready
  static bool _isInitialized = false;

  // YOLO model configuration constants
  static const int inputSize = 640; // Model expects 640x640 input images
  static const double confidenceThreshold = 0.25; // Minimum confidence score to consider a detection
  static const double iouThreshold = 0.45; // Intersection over Union threshold for NMS
  static const int numClasses = 80; // COCO dataset has 80 object classes

  // Initialize the YOLO model and load labels
  static Future<void> initialize() async {
    if (_isInitialized) return; // Skip if already initialized

    try {
      // Load the TensorFlow Lite model from app assets
      _interpreter = await Interpreter.fromAsset('assets/models/yolov8n_float32.tflite');

      // Load the class labels from text file
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData
          .split('\n') // Split by new lines
          .map((label) => label.trim()) // Remove whitespace
          .where((label) => label.isNotEmpty) // Remove empty lines
          .toList(); // Convert to list

      _isInitialized = true; // Mark as initialized
    } catch (e) {
      debugPrint('Error initializing YOLO detector: $e');
      throw Exception('Failed to initialize YOLO detector: $e');
    }
  }

  // Perform object detection on camera feed images
  static Future<List<Detection>> detectFromCameraImage(CameraImage cameraImage) async {
    if (!_isInitialized) await initialize(); // Ensure model is loaded

    try {
      // Convert camera image format to processable image
      final image = _convertCameraImage(cameraImage);
      if (image == null) return []; // Return empty if conversion failed
      // Preprocess image for model input
      final preprocessedImage = _preprocessImage(image);
      // Run model inference
      final output = _runInference(preprocessedImage);
      // Process model output into detection objects
      return _postProcessOutput(output, image.width, image.height);
    } catch (e) {
      debugPrint('Error in live detection: $e');
      return []; // Return empty list on error
    }
  }

  // Perform object detection on image files
  static Future<List<Detection>> detectObjects(File imageFile) async {
    if (!_isInitialized) await initialize(); // Ensure model is loaded

    try {
      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();
      // Decode bytes into image object
      final image = img.decodeImage(imageBytes);

      if (image == null) throw Exception('Failed to decode image');

      // Preprocess image for model input
      final preprocessedImage = _preprocessImage(image);
      // Run model inference
      final output = _runInference(preprocessedImage);
      // Process model output into detection objects
      return _postProcessOutput(output, image.width, image.height);
    } catch (e) {
      debugPrint('Error in object detection: $e');
      rethrow; // Re-throw error for calling code to handle
    }
  }

  // Convert various camera image formats to processable image
  static img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      // Handle different camera formats
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage); // Common Android format
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(cameraImage); // Common iOS format
      } else if (cameraImage.format.group == ImageFormatGroup.jpeg) {
        return _convertJPEGToImage(cameraImage); // JPEG format
      }
      return null; // Unsupported format
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  // Convert YUV420 format to RGB image (common on Android)
  static img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final uvRowStride = cameraImage.planes[1].bytesPerRow; // UV plane row stride
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1; // UV pixel stride
    final image = img.Image(width: width, height: height); // Create empty image

    // Process each pixel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Calculate UV indices for chroma (color) information
        final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final index = y * width + x; // Luma (brightness) index

        // Get YUV components
        final yp = cameraImage.planes[0].bytes[index]; // Luma (Y)
        final up = cameraImage.planes[1].bytes[uvIndex]; // Chroma (U)
        final vp = cameraImage.planes[2].bytes[uvIndex]; // Chroma (V)

        // Convert YUV to RGB using standard conversion formulas
        final r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        final g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        final b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        // Set the pixel in the output image
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return image;
  }

  // Convert BGRA8888 format to RGB image (common on iOS)
  static img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      format: img.Format.uint8,
      numChannels: 4, // BGRA has 4 channels
    );
  }

  // Convert JPEG format to image
  static img.Image? _convertJPEGToImage(CameraImage cameraImage) {
    return img.decodeJpg(cameraImage.planes[0].bytes); // Decode JPEG bytes
  }

  // Preprocess image for YOLO model input
  static List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Resize image to model input size (640x640)
    final resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear, // Linear interpolation for resizing
    );

    // Create 4D tensor: [1, 640, 640, 3] - batch, height, width, RGB channels
    return List.generate(
      1, // Batch size of 1
          (_) => List.generate(
        inputSize, // Height: 640
            (y) => List.generate(
          inputSize, // Width: 640
              (x) {
            // Get pixel at position (x,y)
            final pixel = resizedImage.getPixel(x, y);
            // Normalize pixel values to [0,1] range and return as [R, G, B]
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          },
        ),
      ),
    );
  }

  // Run the YOLO model inference
  static List<List<double>> _runInference(List<List<List<List<double>>>> input) {
    // Create output tensor: [1, 84, 8400] - batch, features, detections
    // YOLOv8 output: 84 features per detection (4 bbox + 80 class scores) × 8400 detections
    final output = List.generate(1, (_) => List.generate(84, (_) => List.filled(8400, 0.0)));

    try {
      // Run the model: input → output
      _interpreter!.run(input, output);
    } catch (e) {
      debugPrint('Error during inference: $e');
      rethrow;
    }

    return output[0]; // Return first batch
  }

  // Process model output into Detection objects
  static List<Detection> _postProcessOutput(
      List<List<double>> output,
      int originalWidth,
      int originalHeight,
      ) {
    final detections = <Detection>[];

    // Process each of the 8400 potential detections
    for (int i = 0; i < 8400; i++) {
      // Extract bounding box coordinates (center x, center y, width, height)
      final x = output[0][i]; // Center x (normalized)
      final y = output[1][i]; // Center y (normalized)
      final w = output[2][i]; // Width (normalized)
      final h = output[3][i]; // Height (normalized)

      // Find the class with highest confidence score
      double maxScore = 0;
      int maxIndex = 0;
      for (int j = 4; j < 84; j++) {
        final score = output[j][i]; // Class probability
        if (score > maxScore) {
          maxScore = score;
          maxIndex = j - 4; // Convert to class index (0-79)
        }
      }

      // Only consider detections above confidence threshold
      if (maxScore > confidenceThreshold) {
        // Calculate scaling factors to convert from 640x640 to original image size
        final scaleX = originalWidth / inputSize;
        final scaleY = originalHeight / inputSize;

        // Convert center coordinates to corner coordinates and scale to original image
        final x1 = ((x - w / 2) * scaleX).clamp(0.0, originalWidth.toDouble());
        final y1 = ((y - h / 2) * scaleY).clamp(0.0, originalHeight.toDouble());
        final x2 = ((x + w / 2) * scaleX).clamp(0.0, originalWidth.toDouble());
        final y2 = ((y + h / 2) * scaleY).clamp(0.0, originalHeight.toDouble());

        // Only add valid bounding boxes (positive area)
        if (x2 > x1 && y2 > y1) {
          detections.add(Detection(
            label: _labels != null && maxIndex < _labels!.length ? _labels![maxIndex] : 'Class $maxIndex',
            confidence: maxScore,
            boundingBox: BoundingBox(x1: x1, y1: y1, x2: x2, y2: y2),
          ));
        }
      }
    }

    // Apply Non-Maximum Suppression to remove duplicate detections
    return _nonMaxSuppression(detections);
  }

  // Non-Maximum Suppression to remove overlapping detections
  static List<Detection> _nonMaxSuppression(List<Detection> detections) {
    if (detections.isEmpty) return [];

    // Sort detections by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selected = <Detection>[]; // Final selected detections
    final suppressed = List<bool>.filled(detections.length, false); // Track suppressed detections

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue; // Skip already suppressed detections

      selected.add(detections[i]); // Add current detection to final list

      // Compare with all remaining detections
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j] || detections[i].label != detections[j].label) continue;

        // Suppress detections of same class with high IoU (overlap)
        if (_calculateIoU(detections[i].boundingBox, detections[j].boundingBox) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return selected;
  }

  // Calculate Intersection over Union (IoU) between two bounding boxes
  static double _calculateIoU(BoundingBox box1, BoundingBox box2) {
    // Calculate intersection rectangle coordinates
    final x1 = box1.x1 > box2.x1 ? box1.x1 : box2.x1; // max of x1s
    final y1 = box1.y1 > box2.y1 ? box1.y1 : box2.y1; // max of y1s
    final x2 = box1.x2 < box2.x2 ? box1.x2 : box2.x2; // min of x2s
    final y2 = box1.y2 < box2.y2 ? box1.y2 : box2.y2; // min of y2s

    // Check if boxes don't intersect
    if (x2 <= x1 || y2 <= y1) return 0.0;

    // Calculate areas
    final intersectionArea = (x2 - x1) * (y2 - y1); // Area of intersection
    final box1Area = (box1.x2 - box1.x1) * (box1.y2 - box1.y1); // Area of box1
    final box2Area = (box2.x2 - box2.x1) * (box2.y2 - box2.y1); // Area of box2
    final unionArea = box1Area + box2Area - intersectionArea; // Area of union

    // IoU = Intersection / Union
    return intersectionArea / unionArea;
  }

  // Clean up resources
  static void dispose() {
    _interpreter?.close(); // Close TensorFlow Lite interpreter
    _interpreter = null;
    _labels = null;
    _isInitialized = false;
  }
}

// Data class to represent a single object detection
class Detection {
  final String label; // Object class name (e.g., 'person', 'car')
  final double confidence; // Detection confidence score (0-1)
  final BoundingBox boundingBox; // Bounding box coordinates

  Detection({required this.label, required this.confidence, required this.boundingBox});

  @override
  String toString() {
    return 'Detection(label: $label, confidence: ${(confidence * 100).toStringAsFixed(1)}%, bbox: $boundingBox)';
  }
}

// Data class to represent a bounding box
class BoundingBox {
  final double x1, y1, x2, y2; // Coordinates: top-left (x1,y1), bottom-right (x2,y2)

  BoundingBox({required this.x1, required this.y1, required this.x2, required this.y2});

  // Computed properties for convenience
  double get width => x2 - x1; // Bounding box width
  double get height => y2 - y1; // Bounding box height
  double get centerX => (x1 + x2) / 2; // Center x coordinate
  double get centerY => (y1 + y2) / 2; // Center y coordinate

  @override
  String toString() {
    return 'BoundingBox(x1: ${x1.toStringAsFixed(1)}, y1: ${y1.toStringAsFixed(1)}, x2: ${x2.toStringAsFixed(1)}, y2: ${y2.toStringAsFixed(1)})';
  }
}