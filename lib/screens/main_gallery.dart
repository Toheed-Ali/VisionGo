import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'live_detection.dart';
import 'object_detection.dart';

class MainGalleryScreen extends StatefulWidget {
  const MainGalleryScreen({super.key});

  @override
  State<MainGalleryScreen> createState() => _MainGalleryScreenState();
}

class _MainGalleryScreenState extends State<MainGalleryScreen> with WidgetsBindingObserver {
  List<AssetEntity> _mediaList = [];
  bool _isLoading = false;
  bool _hasPermission = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  Timer? _refreshTimer;
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh gallery when app comes to foreground
    if (state == AppLifecycleState.resumed && _hasPermission) {
      _loadGalleryImages(showLoading: false);
    }
  }

  void _startAutoRefresh() {
    // Auto-refresh gallery every 5 seconds to detect new images
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _hasPermission && _initialLoadComplete) {
        _loadGalleryImages(showLoading: false);
      }
    });
  }

  Future<void> _requestPermissions() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();

      // Request photo permission using PhotoManager
      final PermissionState photoStatus = await PhotoManager.requestPermissionExtend();

      if (cameraStatus.isGranted && photoStatus.isAuth) {
        if (mounted) {
          setState(() {
            _hasPermission = true;
          });
        }

        // Initialize camera in background
        _initializeCamera();

        // Load gallery images
        await _loadGalleryImages(showLoading: true);
      } else {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _isLoading = false;
          });
          _showPermissionDialog();
        }
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _loadGalleryImages({bool showLoading = false}) async {
    if (!_hasPermission) return;

    // Only show loading indicator if explicitly requested (initial load or manual refresh)
    if (showLoading && !_initialLoadComplete) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();

      if (!ps.isAuth) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasPermission = false;
            _initialLoadComplete = true;
          });
        }
        return;
      }

      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      List<AssetEntity> allMedia = [];

      if (albums.isNotEmpty) {
        // Get all images from the first album (usually "Recent" or "All Photos")
        final int totalCount = await albums[0].assetCountAsync;

        if (totalCount > 0) {
          // Get ALL images, sorted by creation date (newest first)
          allMedia = await albums[0].getAssetListRange(
            start: 0,
            end: totalCount,
          );

          // Sort by creation date in descending order (newest first)
          allMedia.sort((a, b) {
            final aDate = a.createDateTime;
            final bDate = b.createDateTime;
            return bDate.compareTo(aDate);
          });
        }
      }

      // Only update if the list has actually changed to avoid unnecessary rebuilds
      if (mounted) {
        bool hasChanged = _mediaList.length != allMedia.length;

        if (!hasChanged && _mediaList.isNotEmpty && allMedia.isNotEmpty) {
          // Check if the first item is different (new image added)
          hasChanged = _mediaList.first.id != allMedia.first.id;
        }

        if (hasChanged || !_initialLoadComplete) {
          setState(() {
            _mediaList = allMedia;
            _isLoading = false;
            _initialLoadComplete = true;
          });
        } else if (showLoading) {
          // Only update loading state if needed
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading gallery: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initialLoadComplete = true;
        });
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Permissions Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This app needs camera and gallery access to function properly.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text(
                'Open Settings',
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestPermissions();
              },
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onImageTap(AssetEntity asset) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ObjectDetectionScreen(asset: asset),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.1);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: curve),
          );

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _openLiveDetection() {
    if (_isCameraInitialized && _cameraController != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveDetectionScreen(camera: _cameraController!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera is not initialized yet. Please wait...'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: const Center(
                child: Text(
                  'VisionGo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                onTap: _openLiveDetection,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white.withOpacity(0.9),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Open camera',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Images',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_mediaList.length} photos',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_hasPermission && !_isLoading) {
      return const Center(
        child: Text(
          'Camera and Gallery permissions required',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white54,
          ),
        ),
      );
    }

    if (_isLoading && !_initialLoadComplete) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return _buildGalleryGrid();
  }

  Widget _buildGalleryGrid() {
    if (_mediaList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.white24,
            ),
            SizedBox(height: 16),
            Text(
              'No images found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      key: PageStorageKey<String>('gallery_grid'), // Preserve scroll position
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _mediaList.length,
      itemBuilder: (context, index) {
        final asset = _mediaList[index];
        return GestureDetector(
          key: ValueKey(asset.id), // Unique key for each item to prevent rebuilds
          onTap: () => _onImageTap(asset),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<Widget>(
                future: _buildImageThumbnail(asset),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Stack(
                      children: [
                        snapshot.data!,
                        // Subtle gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.1),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white24,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Widget> _buildImageThumbnail(AssetEntity asset) async {
    final thumbnail = await asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
    );

    if (thumbnail != null) {
      return Hero(
        tag: 'image_${asset.id}',
        child: Image.memory(
          thumbnail,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.image,
        color: Colors.white24,
        size: 30,
      ),
    );
  }
}