# VisionGo - AI-Powered Object Detection & Security Camera App

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.3.0+-02569B?style=for-the-badge&logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![TensorFlow](https://img.shields.io/badge/TensorFlow_Lite-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)

**A sophisticated Flutter application combining real-time object detection with intelligent security monitoring**

[Features](#-features) • [Architecture](#-architecture) • [Installation](#-installation) • [Usage](#-usage) • [Security](#-security)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Technologies](#-technologies)
- [Project Structure](#-project-structure)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Security Camera System](#-security-camera-system)
- [Object Detection](#-object-detection)
- [Firebase Integration](#-firebase-integration)
- [Contributing](#-contributing)

---

## 🌟 Overview

**VisionGo** is a cutting-edge mobile application that leverages advanced AI and machine learning to provide real-time object detection capabilities combined with a sophisticated security monitoring system. Built with Flutter and powered by YOLOv8, VisionGo transforms your smartphone into an intelligent visual recognition and security device.

### Key Highlights

- 🎯 **Real-time Object Detection**: Detect and identify 80+ different object classes using YOLOv8
- 🔒 **Security Camera System**: Transform your device into a smart security camera with remote monitoring
- 📸 **Live Camera Feed**: Process and analyze video streams in real-time
- 🔔 **Smart Alerts**: Receive instant notifications when monitored objects are detected
- ☁️ **Cloud-Powered**: Full Firebase integration for authentication, storage, and real-time updates
- 🎨 **Modern UI**: Beautiful, intuitive interface with Instagram-inspired navigation
- 📊 **Detection History**: View and manage all detected objects in an organized gallery

---

## ✨ Features

### 🔍 Object Detection

- **80 Object Classes**: Detect a wide range of objects including:
  - People, vehicles (cars, bicycles, motorcycles, buses, trucks)
  - Animals (cats, dogs, birds, horses, etc.)
  - Household items (furniture, electronics, kitchenware)
  - Food items, sports equipment, and more
- **YOLOv8 Model**: State-of-the-art neural network for fast and accurate detection
- **Real-time Processing**: Process camera feed at high FPS for smooth detection
- **Bounding Boxes**: Visual overlay showing detected objects with confidence scores
- **Gallery Integration**: Automatically save and organize detected objects

### 🛡️ Security Camera System

- **Device Pairing**: Secure pairing system using unique 8-digit codes
- **Remote Monitoring**: Monitor camera feed from any paired device
- **Object-Specific Alerts**: Select specific objects to monitor (e.g., only alert for "person")
- **Live Feed Streaming**: Real-time camera feed accessible remotely
- **Push Notifications**: Instant alerts when monitored objects are detected
- **Multi-Device Support**: Pair and monitor multiple security cameras
- **Photo Capture**: Automatically capture and save photos when threats detected
- **Flash Control**: Toggle camera flash for low-light monitoring
- **Session Management**: Persistent monitoring sessions survive app restarts

### 👤 User Management

- **Firebase Authentication**: Secure email/password authentication
- **User Profiles**: Personalized user accounts with profile management
- **Onboarding Flow**: Smooth introduction for first-time users
- **Account Settings**: Manage profile information and preferences

### 📱 User Interface

- **Modern Design**: Clean, professional interface with dark mode support
- **Instagram-Style Navigation**: Familiar bottom navigation with profile pictures
- **Responsive Layout**: Optimized for various screen sizes
- **Smooth Animations**: Polished transitions and micro-interactions
- **Icon Integration**: Custom icons and visual assets

---

## 🏗️ Architecture

### Application Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      App Launch                             │
│  (main.dart - Firebase initialization)                      │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│              Onboarding Check                               │
│  (First time user? Show onboarding)                         │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│           Authentication Gate                               │
│  (Login/Signup screens with Firebase Auth)                  │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│              Home Screen (Tab Navigation)                   │
│                                                             │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐   │
│  │  Camera  │ Gallery  │ Security │ Monitor  │ Profile  │   │
│  └────┬─────┴─────┬────┴────┬─────┴────┬─────┴────┬─────┘   │
│       │           │         │          │          │         │
│       ▼           ▼         ▼          ▼          ▼         │
│      Live       Main     Security  Security    Account      │
│    Detection   Gallery    Camera    Monitor    Setting      │
└─────────────────────────────────────────────────────────────┘
```

### Component Architecture

```
┌────────────────────────────────────────────────────────────┐
│                     Presentation Layer                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Screens (12 screens)                                │  │
│  │  • Onboarding  • Login  • Signup  • Home             │  │
│  │  • Live Detection  • Object Detection                │  │
│  │  • Main Gallery  • Security Camera                   │  │
│  │  • Security Monitor  • Security Screen               │  │
│  │  • Manage Devices  • Account                         │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────┬──────────────────────────────────┘
                          │
┌─────────────────────────┴──────────────────────────────────┐
│                     Service Layer                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  YoloDetector       - Object detection with YOLOv8   │  │
│  │  FirebaseSecurityService - Security pairing & alerts │  │
│  │  NotificationService - Push notifications            │  │
│  │  FCMApiService      - Cloud messaging API calls      │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────┬──────────────────────────────────┘
                          │
┌─────────────────────────┴──────────────────────────────────┐
│                   Infrastructure Layer                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Firebase Auth      - User authentication            │  │
│  │  Firebase Database  - Real-time data sync            │  │
│  │  Cloud Firestore    - Document storage               │  │
│  │  Firebase Messaging - Push notifications             │  │
│  │  TFLite             - ML model inference             │  │
│  │  Camera             - Device camera access           │  │
│  │  Photo Manager      - Gallery integration            │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Technologies

### Core Framework

- **Flutter 3.3.0+**: Cross-platform mobile development framework
- **Dart 3.0+**: Programming language optimized for UI development

### AI & Machine Learning

- **TensorFlow Lite**: Lightweight ML framework for mobile
- **YOLOv8**: You Only Look Once v8 - Real-time object detection model
- **Custom TFLite Model**: Optimized `yolov8n_float32.tflite` for mobile inference

### Backend & Cloud Services

- **Firebase Core**: Firebase SDK initialization
- **Firebase Authentication**: User authentication and management
- **Firebase Realtime Database**: Real-time data synchronization
- **Cloud Firestore**: Scalable NoSQL database
- **Firebase Cloud Messaging (FCM)**: Push notification service
- **Firebase Admin SDK**: Server-side Firebase operations

### Camera & Media

- **Camera Plugin**: Access device camera for live feed
- **Camera Android**: Android-specific camera optimizations
- **Photo Manager**: Gallery and photo management
- **Image Package**: Image processing and manipulation
- **Path Provider**: File system path access

### UI & UX

- **Google Fonts**: Beautiful typography (custom fonts)
- **Material Design**: Google's design system
- **Flutter Local Notifications**: Local notification handling

### Utilities

- **Shared Preferences**: Local data persistence
- **Permission Handler**: Runtime permission management
- **Device Info Plus**: Device information access
- **HTTP**: REST API communication
- **Intl**: Internationalization and date formatting
- **Path**: File path manipulation
- **Google APIs Auth**: OAuth 2.0 authentication

---

## 📁 Project Structure

```
object_detection/
├── lib/
│   ├── main.dart                          # App entry point & initialization
│   ├── firebase_options.dart              # Firebase configuration
│   │
│   ├── screens/                           # UI Screens (12 screens)
│   │   ├── onboarding_screen.dart         # First-time user introduction
│   │   ├── login.dart                     # User login
│   │   ├── signup.dart                    # User registration
│   │   ├── home_screen.dart               # Main tab navigation
│   │   ├── live_detection.dart            # Real-time camera detection
│   │   ├── object_detection.dart          # Object detection processing
│   │   ├── main_gallery.dart              # Photo gallery with detection history
│   │   ├── security_camera_screen.dart    # Security camera mode
│   │   ├── security_monitor_screen.dart   # Remote monitoring view
│   │   ├── security_screen.dart           # Security system management
│   │   ├── manage_devices_section.dart    # Paired devices management
│   │   └── account_screen.dart            # User profile & settings
│   │
│   └── services/                          # Business logic & APIs (4 services)
│       ├── yolo_detector.dart             # YOLOv8 object detection service
│       ├── firebase_security_service.dart # Security pairing & monitoring
│       ├── notification_service.dart      # Push notification handler
│       └── fcm_api_service.dart          # Firebase Cloud Messaging API
│
├── assets/
│   ├── models/
│   │   └── yolov8n_float32.tflite        # YOLOv8 nano model (optimized)
│   ├── labels.txt                         # 80 COCO dataset object classes
│   ├── icons/                             # App icons and images
│   │   ├── app_icon.png                   # Launcher icon
│   │   ├── Camera.jpeg                    # Camera tab icon
│   │   ├── Gallery.png                    # Gallery tab icon
│   │   └── security_image.jpg             # Security feature image
│   └── vision-go-b1cda-firebase-adminsdk-fbsvc-*.json  # Firebase Admin SDK (gitignored)
│
├── android/                               # Android-specific configuration
├── ios/                                   # iOS-specific configuration
├── web/                                   # Web platform support
├── windows/                               # Windows platform support
├── linux/                                 # Linux platform support
├── macos/                                 # macOS platform support
│
├── functions/                             # Firebase Cloud Functions
├── firestore.rules                        # Firestore security rules
├── firebase.json                          # Firebase project configuration
├── .firebaserc                            # Firebase project aliases
│
├── pubspec.yaml                           # Flutter dependencies & assets
├── analysis_options.yaml                  # Dart analyzer configuration
├── .gitignore                             # Git ignore rules
└── README.md                              # This file
```

---

## 🚀 Installation

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.3.0 or higher): [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (3.0 or higher): Included with Flutter
- **Android Studio** or **Xcode**: For Android/iOS development
- **Git**: Version control system
- **Firebase Account**: [Create Firebase Project](https://console.firebase.google.com/)

### Step 1: Clone the Repository

```bash
git clone https://github.com/Toheed-Ali/VisionGo.git
cd VisionGo
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Firebase Setup

#### 3.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" and follow the setup wizard
3. Enable the following services:
   - **Authentication** (Email/Password provider)
   - **Realtime Database**
   - **Cloud Firestore**
   - **Cloud Messaging**

#### 3.2 Add Android App

1. In Firebase Console, click "Add app" → Select Android
2. Register app with package name: `com.yourcompany.visiongo`
3. Download `google-services.json`
4. Place it in `android/app/` directory

#### 3.3 Add iOS App (if targeting iOS)

1. In Firebase Console, click "Add app" → Select iOS
2. Register app with bundle ID
3. Download `GoogleService-Info.plist`
4. Add it to your Xcode project

#### 3.4 Configure FlutterFire

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for all platforms
flutterfire configure
```

This will generate/update `lib/firebase_options.dart`

#### 3.5 Firebase Admin SDK (for Security Features)

1. In Firebase Console → Project Settings → Service Accounts
2. Generate new private key
3. Save the JSON file as:
   ```
   assets/vision-go-b1cda-firebase-adminsdk-fbsvc-[key-id].json
   ```
   ⚠️ **Important**: This file is already in `.gitignore` for security

### Step 4: Update Configuration

#### Update `pubspec.yaml`

Ensure all dependencies are properly listed (should be complete in the repo)

#### Update Firebase Rules

Deploy Firestore security rules:

```bash
firebase deploy --only firestore:rules
```

### Step 5: Run the Application

```bash
# Run on connected device/emulator
flutter run

# Or run in release mode for better performance
flutter run --release
```

---

## ⚙️ Configuration

### App Configuration

Edit `lib/main.dart` to customize:
- App name and theme
- Initial route
- Debug settings

### Firebase Configuration

The app uses the following Firebase structure:

#### Realtime Database Structure

```json
{
  "security_pairings": {
    "XXXXXXXX": {                          // 8-digit pairing code
      "code": "XXXXXXXX",
      "createdAt": 1234567890,
      "monitoredObjects": ["person", "car"],
      "isActive": true,
      "cameraDeviceId": "device-123",
      "monitoringDeviceId": "device-456",
      "cameraFCMToken": "fcm-token-...",
      "monitoringFCMToken": "fcm-token-..."
    }
  },
  "user_devices": {
    "user_uid": {
      "device_id": {
        "deviceName": "Device Name",
        "fcmToken": "fcm-token-...",
        "lastSeen": 1234567890
      }
    }
  }
}
```

#### Firestore Collections

```
users/
  {user_id}/
    email: string
    createdAt: timestamp
    
detections/
  {detection_id}/
    userId: string
    objectLabel: string
    confidence: number
    timestamp: timestamp
    imagePath: string
```

### Model Configuration

The app uses **YOLOv8 Nano (Float32)** model:
- **File**: `assets/models/yolov8n_float32.tflite`
- **Input**: 640x640 RGB image
- **Output**: 80 object classes
- **Classes**: Defined in `assets/labels.txt`

To use a different model:
1. Replace the `.tflite` file
2. Update `assets/labels.txt` if classes change
3. Modify `lib/services/yolo_detector.dart` if input/output format differs

---

## 📖 Usage

### 1. First Launch - Onboarding

On first launch, users see a beautiful onboarding screen explaining VisionGo's features.

### 2. Authentication

- **Sign Up**: Create account with email and password
- **Login**: Access existing account
- All authentication handled securely via Firebase

### 3. Home Screen Navigation

The app features 5 main tabs:

#### 📷 Camera Tab (Live Detection)
- Real-time object detection using device camera
- Visual bounding boxes around detected objects
- Confidence scores displayed for each detection
- Capture and save detected objects

#### 🖼️ Gallery Tab
- View all saved detections
- Browse photos organized by date
- Filter by object type
- Delete unwanted items

#### 🛡️ Security Tab
- Enter security camera mode
- Generate pairing codes
- Select objects to monitor
- View active monitoring sessions

#### 📊 Monitor Tab
- View live feed from paired security cameras
- Receive real-time alerts
- Manage connected devices
- Review detection history

#### 👤 Profile Tab
- View/edit profile information
- Manage account settings
- View app information
- Logout

### 4. Object Detection

#### Using Live Detection:

1. Tap **Camera** tab
2. Point camera at objects
3. Detection happens automatically
4. Tap capture button to save detection
5. View results in Gallery

#### Detected Object Classes (80 total):

**People & Animals**: person, cat, dog, horse, sheep, cow, elephant, bear, zebra, giraffe, bird

**Vehicles**: bicycle, car, motorcycle, airplane, bus, train, truck, boat

**Indoor Objects**: chair, couch, bed, dining table, toilet, tv, laptop, mouse, keyboard, cell phone, book, clock

**Kitchen**: bottle, wine glass, cup, fork, knife, spoon, bowl, microwave, oven, toaster, sink, refrigerator

**Food**: banana, apple, sandwich, orange, broccoli, carrot, hot dog, pizza, donut, cake

**And many more...**

### 5. Security Camera System

#### Setup as Security Camera:

1. Navigate to **Security** tab
2. Tap "**Start Security Camera**"
3. A 6-digit code is generated (e.g., `12345678`)
4. Select objects to monitor (e.g., "person", "car")
5. Camera starts monitoring
6. Share code with monitoring device

#### Monitor from Another Device:

1. Open VisionGo on monitoring device
2. Navigate to **Monitor** tab
3. Tap "**Enter Pairing Code**"
4. Enter the 6-digit code from camera device
5. View live feed and receive alerts

#### Security Features:

- **Selective Monitoring**: Only get alerts for chosen objects
- **Photo Capture**: Auto-saves photos when threats detected
- **Push Notifications**: Instant alerts sent to monitoring device
- **Flash Control**: Enable flash for night monitoring
- **Persistent Sessions**: Monitoring continues even if app restarts
- **Multi-Device**: Monitor multiple cameras simultaneously

---

## 🔒 Security Camera System

### How It Works

The security system uses a **device pairing mechanism**:

```
┌─────────────────┐                    ┌─────────────────┐
│  Camera Device  │                    │ Monitor Device  │
│                 │                    │                 │
│  1. Generate    │◄───────────────────┤ 3. Enter Code   │
│     8-digit code│       Share Code   │                 │
│                 │                    │                 │
│  2. Start       │                    │ 4. View Feed &  │
│     Monitoring  │◄───Real-time Data──┤    Get Alerts   │
│                 │    via Firebase    │                 │
└─────────────────┘                    └─────────────────┘
```

### Pairing Process

1. **Code Generation**: Camera device generates unique 8-digit code
2. **Firebase Registration**: Code and device info stored in Firebase Realtime Database
3. **Code Sharing**: User shares code with monitoring device
4. **Pairing**: Monitor device validates and registers with code
5. **Connection**: Secure bidirectional communication established

### Alert System

When a monitored object is detected:

1. **Detection**: YOLOv8 identifies object in camera feed
2. **Filtering**: Check if object matches monitored list
3. **Photo Capture**: High-quality photo saved locally
4. **Cloud Upload**: Detection data sent to Firebase
5. **Push Notification**: FCM sends alert to monitoring device
6. **Alert Display**: Monitor device shows notification with details

### Security Measures

- ✅ **Time-Limited Codes**: Pairing codes can expire
- ✅ **Device Authentication**: Both devices must be authenticated users
- ✅ **Encrypted Communication**: All data transmitted via Firebase (HTTPS)
- ✅ **FCM Tokens**: Secure device-to-device messaging
- ✅ **Session Management**: Active session tracking and validation
- ✅ **Permission-Based**: Camera and notification permissions required

---

## 🤖 Object Detection

### YOLOv8 Implementation

VisionGo uses **YOLOv8 Nano** - the fastest YOLO variant optimized for mobile:

#### Model Specifications

- **Architecture**: YOLOv8n (Nano)
- **Framework**: TensorFlow Lite
- **Precision**: Float32
- **Input Size**: 640×640×3 (RGB)
- **Output**: Bounding boxes + confidence scores
- **Classes**: 80 (COCO dataset)
- **Performance**: ~30-60 FPS on modern devices

#### Detection Pipeline

```
Camera Frame (1920×1080)
        ↓
Preprocessing (resize to 640×640, normalize)
        ↓
TFLite Model Inference
        ↓
Post-processing (NMS, threshold filtering)
        ↓
Bounding Box Rendering
        ↓
Display on Screen
```

### Detection Service (`yolo_detector.dart`)

Key methods:

- `loadModel()`: Load TFLite model into memory
- `detectObjects(imageData)`: Run inference on image
- `runInference(input)`: Execute model prediction
- `processOutput(output)`: Parse and filter results
- `dispose()`: Clean up resources

### Performance Optimization

- **Asynchronous Processing**: Detection runs in isolates
- **Frame Skipping**: Process every Nth frame to maintain FPS
- **Model Quantization**: Float32 for balance of speed and accuracy
- **Resolution Scaling**: 640×640 input for fast inference
- **Non-Maximum Suppression (NMS)**: Remove duplicate detections

---

## 🔥 Firebase Integration

### Authentication Flow

```dart
// Sign Up
await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email,
  password: password,
);

// Login
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);

// Logout
await FirebaseAuth.instance.signOut();
```

### Realtime Database Operations

```dart
// Create Pairing
final ref = FirebaseDatabase.instance.ref('security_pairings/$code');
await ref.set({
  'code': code,
  'createdAt': ServerValue.timestamp,
  'monitoredObjects': selectedObjects,
  'isActive': true,
});

// Listen for Changes
ref.onValue.listen((event) {
  final data = event.snapshot.value;
  // Handle real-time updates
});
```

### Cloud Messaging

```dart
// Send Notification
await FCMApiService.sendNotification(
  fcmToken: deviceToken,
  title: 'Threat Detected',
  body: 'Person detected at 95% confidence',
  data: {'objectLabel': 'person', 'confidence': '0.95'},
);
```

### Firestore Storage

```dart
// Save Detection
await FirebaseFirestore.instance.collection('detections').add({
  'userId': currentUser.uid,
  'objectLabel': 'person',
  'confidence': 0.95,
  'timestamp': FieldValue.serverTimestamp(),
  'imagePath': photoPath,
});
```

---

## 🎨 UI/UX Features

### Design Philosophy

- **Dark Mode First**: Modern dark theme with teal accents
- **Minimalist**: Clean interface without clutter
- **Familiar Navigation**: Instagram-inspired bottom tabs
- **Responsive**: Adapts to different screen sizes
- **Accessible**: High contrast, readable fonts

### Color Scheme

```dart
Primary: Colors.tealAccent
Background: Colors.black
Surface: Colors.grey[900]
Text: Colors.white
Accent: Colors.pink
```

### Custom Components

- **Circle Buttons**: Reusable circular action buttons
- **Detection Painter**: Custom painter for bounding boxes
- **Object Selection Sheet**: Bottom sheet for object filtering
- **Loading Indicators**: Smooth loading animations

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Camera Not Working

```
Solution:
- Check camera permissions in device settings
- Ensure camera is not in use by another app
- Restart the application
```

#### 2. Detection Not Starting

```
Solution:
- Verify TFLite model is in assets/models/
- Check labels.txt exists in assets/
- Review logs for model loading errors
```

#### 3. Firebase Connection Issues

```
Solution:
- Verify internet connection
- Check Firebase project configuration
- Ensure google-services.json is correctly placed
- Re-run flutterfire configure
```

#### 4. Notifications Not Received

```
Solution:
- Enable notification permissions
- Check FCM token generation
- Verify Firebase Admin SDK setup
- Test with Firebase Console debug tool
```

#### 5. Pairing Code Not Working

```
Solution:
- Ensure both devices are logged in
- Check code hasn't expired
- Verify Realtime Database rules
- Check network connectivity
```

---

## 📦 Building for Production

### Android APK

```bash
# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

### iOS IPA

```bash
# Build for iOS
flutter build ios --release
```

### Configure App Icons

Icons are managed via `flutter_launcher_icons`:

```bash
flutter pub run flutter_launcher_icons:main
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 👨‍💻 Developer

**Toheed Ali**

- GitHub: [@Toheed-Ali](https://github.com/Toheed-Ali)
- Repository: [VisionGo](https://github.com/Toheed-Ali/VisionGo)

---

## 🙏 Acknowledgments

- **YOLOv8**: Ultralytics for the amazing object detection model
- **Flutter Team**: For the excellent cross-platform framework
- **Firebase**: For comprehensive backend services
- **TensorFlow**: For TensorFlow Lite mobile ML framework
- **COCO Dataset**: For the 80 object classes

---

## 📞 Support

For issues, questions, or suggestions:

1. **GitHub Issues**: [Create an issue](https://github.com/Toheed-Ali/VisionGo/issues)
2. **Discussions**: Use GitHub Discussions for questions
3. **Email**: Contact via GitHub profile

---

<div align="center">

**Made with ❤️ using Flutter**

⭐ Star this repository if you find it helpful!

</div>
