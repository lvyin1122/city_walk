import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mambo/services/cloudinary_service.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:mambo/theme/app_colors.dart';

class QuickStartMapPage extends StatefulWidget {
  const QuickStartMapPage({super.key});

  @override
  State<QuickStartMapPage> createState() => _QuickStartMapPageState();
}

class _QuickStartMapPageState extends State<QuickStartMapPage> {
  static const LatLng _defaultPosition = LatLng(37.7749, -122.4194);
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  bool _isRecording = false;
  bool _isUploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();
  final GraphQLService _graphQLService = GraphQLService();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _timerDisplay = '00:00:00';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _setLocationReady(null);
          return;
        }
      }

      final permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted &&
          permissionGranted != PermissionStatus.grantedLimited) {
        _setLocationReady(null);
        return;
      }

      final locationData = await location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Location request timed out'),
      );
      if (locationData.latitude != null && locationData.longitude != null) {
        _setLocationReady(
          LatLng(locationData.latitude!, locationData.longitude!),
        );
      } else {
        _setLocationReady(null);
      }
    } catch (_) {
      _setLocationReady(null);
    }
  }

  void _setLocationReady(LatLng? position) {
    if (mounted) {
      setState(() => _userLocation = position);
      if (position != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(position, 15),
        );
      }
    }
  }

  LatLng get _initialPosition => _userLocation ?? _defaultPosition;

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _stopwatch.start();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final elapsed = _stopwatch.elapsed;
          final hours = elapsed.inHours;
          final minutes = elapsed.inMinutes.remainder(60);
          final seconds = elapsed.inSeconds.remainder(60);
          _timerDisplay =
              '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _stopwatch.reset();
    setState(() {
      _isRecording = false;
      _timerDisplay = '00:00:00';
    });
  }

  Future<Map<String, dynamic>?> _showPhotoSourceBottomSheet() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) return null;

    final XFile? photo = await _picker.pickImage(source: source);
    if (photo == null) return null;
    return {'file': photo, 'source': source};
  }

  Future<File> _compressImage(File file) async {
    const int maxSize = 128 * 1024; // 128kb
    final int fileSize = await file.length();

    if (fileSize <= maxSize) {
      return file;
    }

    final double compressionRatio = maxSize / fileSize;
    final int quality = (compressionRatio * 100).round().clamp(1, 100);

    final List<int> compressedBytes =
        (await FlutterImageCompress.compressWithFile(
              file.path,
              quality: quality,
            ))
            as List<int>;

    final String compressedPath = '${file.path}_compressed.jpg';
    final File compressedFile = File(compressedPath);
    await compressedFile.writeAsBytes(compressedBytes);

    return compressedFile;
  }

  Future<void> _takePhoto() async {
    try {
      final result = await _showPhotoSourceBottomSheet();
      if (result != null) {
        final XFile photo = result['file'];
        setState(() => _isUploadingPhoto = true);

        final File compressedFile = await _compressImage(File(photo.path));
        final String? imageUrl =
            await CloudinaryService.uploadImage(compressedFile);

        setState(() => _isUploadingPhoto = false);

        if (imageUrl != null && mounted) {
          _showAddLogBottomSheet(imageUrl);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload photo')),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  Future<void> _showAddLogBottomSheet(String photoUrl) async {
    final textController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add a new log',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You can add some additional writing here (optional)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write something...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      foregroundColor: AppColors.buttonTextColor,
                      backgroundColor: AppColors.primaryColor,
                    ),
                    onPressed: () async {
                      await _graphQLService.addLog(
                        photoUrl: photoUrl,
                        text: textController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    textController.dispose();
  }

  Widget _buildStartRecordUI() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            foregroundColor: AppColors.buttonTextColor,
            backgroundColor: AppColors.primaryColor,
          ),
          onPressed: _startRecording,
          child: const Text('Start Record'),
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _timerDisplay,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isUploadingPhoto ? null : _takePhoto,
            icon: _isUploadingPhoto
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo),
            label: Text(_isUploadingPhoto ? 'Uploading...' : 'Add Photo'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              foregroundColor: AppColors.buttonTextColor,
              backgroundColor: AppColors.alertColor,
            ),
            onPressed: _stopRecording,
            child: const Text('Stop Record'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GoogleMap(
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  zoomGesturesEnabled: true,
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 15,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (_userLocation != null) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(_userLocation!, 15),
                      );
                    }
                  },
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: FloatingActionButton(
                    heroTag: 'backButton',
                    mini: true,
                    backgroundColor: Theme.of(context).cardColor,
                    child: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: _isRecording ? _buildRecordingUI() : _buildStartRecordUI(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
