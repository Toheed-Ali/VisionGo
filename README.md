# VisionGo

A professional Flutter-based mobile application that combines real-time object detection with advanced security monitoring capabilities. VisionGo leverages YOLOv8 machine learning models to provide intelligent image analysis and cross-device security alert systems.

## Overview

VisionGo is a comprehensive computer vision application designed for both everyday object detection and specialized security monitoring. The app enables users to analyze images from their gallery, perform live camera detection, and establish secure device pairings for real-time security surveillance with instant push notifications.


## Key Features

### Object Detection
- **Real-time Object Detection**: Live camera feed analysis using YOLOv8 neural network model
- **Gallery Analysis**: Process and analyze existing images from device gallery with bounding box visualization
- **Multi-Object Recognition**: Supports detection of 80+ object classes from the COCO dataset
- **Confidence Scoring**: Displays detection confidence levels with color-coded bounding boxes
- **Non-Maximum Suppression**: Advanced filtering to eliminate duplicate detections

### Security Monitoring System
- **Device Pairing**: Secure pairing mechanism between camera and monitor devices using unique codes
- **Cross-Device Communication**: Real-time alert relay between paired devices via Firebase Realtime Database
- **Selective Monitoring**: Monitor specific object categories based on user preferences
- **Live Security Alerts**: Instant push notifications when monitored objects are detected
- **Alert History**: Comprehensive log of all security events with timestamps and confidence scores
- **Background Detection**: Continuous monitoring with automatic image capture and analysis
- **Persistent Pairing**: Device pairings survive app restarts and are managed through user profile

### Gallery and Media Management
- **Auto-Refresh Gallery**: Automatic detection of new images with periodic updates
- **Optimized Thumbnails**: Fast loading with efficient thumbnail caching
- **Permission Management**: Seamless handling of camera and storage permissions
- **Responsive Grid Layout**: Beautiful, organized display of gallery images

### Authentication and User Management
- **Firebase Authentication**: Secure user registration and login system
- **Onboarding Experience**: First-time user guidance and feature introduction
- **Account Management**: User profile with device pairing status and history
- **Session Persistence**: Automatic login state management across app launches

### Push Notifications
- **Firebase Cloud Messaging**: Real-time notification delivery using FCM
- **Background Notifications**: Receive alerts even when app is closed or terminated
- **Custom Notification Channels**: Separate channels for security alerts and general notifications
- **Platform-Specific Optimization**: Tailored notification behavior for Android and iOS
- **Cloud Functions Integration**: Server-side notification processing for reliability

## Technical Architecture

### Frontend (Flutter)
- **Framework**: Flutter SDK 3.3.0+
- **State Management**: StatefulWidgets with lifecycle management
- **Navigation**: Material page routing with custom transitions
- **UI Design**: Dark theme with modern glassmorphism and gradient effects

### Machine Learning
- **Model**: YOLOv8n (nano variant) optimized for mobile deployment
- **Format**: TensorFlow Lite (.tflite) for efficient on-device inference
- **Input Processing**: 640x640 image preprocessing with normalization
- **Post-Processing**: Custom bounding box extraction and NMS implementation

### Backend Services
- **Firebase Realtime Database**: Real-time data synchronization for device pairings and alerts
- **Firebase Cloud Functions**: Server-side notification relay and alert cleanup
- **Firebase Cloud Messaging**: Push notification infrastructure
- **Firebase Authentication**: Secure user identity management

### Local Storage
- **SharedPreferences**: User preferences, onboarding status, and active pairing persistence
- **Photo Manager**: Gallery access and image metadata management
- **Camera Plugin**: Direct camera hardware access for live detection

## Technologies Used

### Core Dependencies
- **flutter**: Mobile app framework
- **firebase_core**: Firebase initialization
- **firebase_auth**: User authentication
- **firebase_database**: Realtime database integration
- **firebase_messaging**: Push notifications
- **cloud_firestore**: Document database (optional storage)

### Media and Camera
- **camera**: Camera hardware access and image capture
- **camera_android**: Android-specific camera optimizations
- **photo_manager**: Gallery and photo library access
- **permission_handler**: Runtime permission management

### Machine Learning
- **tflite_flutter**: TensorFlow Lite model inference
- **image**: Image processing and manipulation

### UI and Utilities
- **google_fonts**: Custom typography
- **shared_preferences**: Local data persistence
- **path_provider**: File system access
- **intl**: Date and time formatting
- **flutter_local_notifications**: Local notification display
- **device_info_plus**: Device identification

### Backend (Firebase Cloud Functions)
- **firebase-functions**: Cloud function runtime
- **firebase-admin**: Firebase Admin SDK for server operations
- **Node.js**: Runtime environment

## Project Structure

```
lib/
├── main.dart                          # Application entry point and initialization
├── firebase_options.dart              # Firebase configuration
├── screens/                           # UI screens
│   ├── onboarding_screen.dart        # First-time user experience
│   ├── login.dart                    # User login
│   ├── signup.dart                   # User registration
│   ├── home_screen.dart              # Main navigation hub
│   ├── main_gallery.dart             # Gallery view with image grid
│   ├── object_detection.dart         # Single image detection view
│   ├── live_detection.dart           # Real-time camera detection
│   ├── security_screen.dart          # Security role selection
│   ├── security_camera_screen.dart   # Camera device mode
│   ├── security_monitor_screen.dart  # Monitor device mode
│   ├── account_screen.dart           # User profile and settings
│   └── manage_devices_section.dart   # Paired devices management
├── services/                          # Business logic and integrations
│   ├── yolo_detector.dart            # YOLOv8 inference engine
│   ├── firebase_security_service.dart # Device pairing and alerts
│   ├── notification_service.dart     # FCM and local notifications
│   └── security_service.dart         # Security utilities
├── assets/
│   ├── models/
│   │   └── yolov8n_float32.tflite   # YOLOv8 model
│   ├── labels.txt                    # Object class labels
│   └── icons/                        # App icons and images
└── functions/
    └── index.js                      # Firebase Cloud Functions
```

## Setup and Installation

### Prerequisites
- Flutter SDK 3.3.0 or higher
- Dart SDK 3.3.0 or higher
- Android Studio or Xcode for mobile development
- Firebase project with Realtime Database, Authentication, and Cloud Messaging enabled
- Node.js and npm for Firebase Cloud Functions

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd object_detection
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Firebase Authentication (Email/Password)
   - Enable Firebase Realtime Database
   - Enable Firebase Cloud Messaging
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place configuration files in appropriate platform directories

4. **Generate Firebase options**
   ```bash
   flutterfire configure
   ```

5. **Deploy Firebase Cloud Functions**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

6. **Run the application**
   ```bash
   flutter run
   ```

### Firebase Realtime Database Rules

Configure security rules in Firebase Console:

```json
{
  "rules": {
    "security-pairings": {
      "$pairingCode": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "user-pairings": {
      "$userId": {
        ".read": "auth.uid == $userId",
        ".write": "auth.uid == $userId"
      }
    }
  }
}
```

## Usage Guide

### Basic Object Detection

1. **Gallery Detection**
   - Navigate to the Gallery tab (home screen)
   - Tap any image from your gallery
   - View detected objects with bounding boxes and labels
   - See confidence scores for each detection

2. **Live Camera Detection**
   - Tap "Open camera" button on Gallery screen
   - Point camera at objects
   - View real-time detection overlays
   - Capture images for later analysis

### Security Monitoring

1. **Setup as Camera Device**
   - Navigate to Security tab
   - Select "Camera" role
   - Choose objects to monitor from the list
   - Note the 6-digit pairing code displayed

2. **Setup as Monitor Device**
   - On a second device, navigate to Security tab
   - Select "Monitor" role
   - Enter the pairing code from camera device
   - View real-time alerts when monitored objects are detected

3. **Manage Pairings**
   - Go to Account tab
   - View all active device pairings
   - Unpair devices as needed
   - Review pairing history

### Notifications

- Ensure notification permissions are granted
- Alerts are sent even when app is in background or closed
- Tap notifications to open monitor screen
- Review alert history with timestamps and confidence scores

## How It Works

### Object Detection Pipeline

1. **Image Acquisition**: Camera or gallery image is loaded
2. **Preprocessing**: Image resized to 640x640 and normalized
3. **Inference**: YOLOv8 model processes the image tensor
4. **Post-Processing**: Bounding boxes extracted and filtered using NMS
5. **Visualization**: Results rendered with color-coded boxes and labels

### Security Monitoring Flow

1. **Pairing Establishment**: Camera device generates unique code and creates entry in Firebase
2. **Monitor Connection**: Monitor device validates code and subscribes to alerts
3. **Detection Loop**: Camera device continuously captures and analyzes images
4. **Alert Generation**: When monitored object detected, alert written to Firebase
5. **Cloud Function Trigger**: Firebase function sends push notification to monitor device
6. **Notification Delivery**: FCM delivers alert even if app is backgrounded
7. **Alert Display**: Monitor device shows notification and updates alert list

### Cross-Device Communication

```
Camera Device               Firebase                Monitor Device
     |                         |                          |
     |--[Create Pairing]------>|                          |
     |                         |<------[Validate Code]----|
     |                         |                          |
     |--[Detect Object]------->|                          |
     |                         |--[Cloud Function]------->|
     |                         |                          |
     |                         |<--[Subscribe to Alerts]--|
     |--[Add Alert]----------->|                          |
     |                         |--[Push Notification]---->|
```

## Performance Optimizations

- **Model Selection**: YOLOv8n (nano) variant for optimal mobile performance
- **Asynchronous Processing**: Non-blocking detection operations
- **Thumbnail Caching**: Efficient gallery loading with reusable thumbnails
- **Background Detection Control**: Configurable detection intervals to balance battery life
- **Stream Management**: Automatic reconnection and heartbeat for Firebase connections
- **Memory Management**: Proper disposal of camera controllers and image resources

## Platform Support

- **Android**: API Level 21+ (Android 5.0 Lollipop)
- **iOS**: iOS 11.0+ (configured via platform settings)
- **Background Notifications**: Fully supported on both platforms

## Security Features

- **Secure Authentication**: Firebase Authentication with email/password
- **Code-Based Pairing**: 6-digit random codes for device pairing
- **Database Rules**: User-scoped data access in Firebase
- **FCM Token Management**: Secure storage and refresh of notification tokens
- **Session Management**: Automatic token refresh and validation

## License

This project is licensed under standard terms. See project documentation for details.

## Support and Issues

For bug reports, feature requests, or technical support, please use the project's issue tracking system.

## Version

Current version: 1.0.0+1

---

Built with Flutter and Firebase. Powered by YOLOv8 for state-of-the-art object detection.
