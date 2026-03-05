import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mambo/features/home/log/log_review_page.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:mambo/services/cloudinary_service.dart';
import 'package:mambo/services/log_service.dart';
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
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  bool _isLogging = false;
  bool _isUploadingPhoto = false;
  bool _isAddingLog = false;
  final ImagePicker _picker = ImagePicker();
  final GraphQLService _graphQLService = GraphQLService();

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

  /// Fetches current location on demand. Use when adding a log entry to get
  /// accurate coordinates at photo time, since myLocationEnabled does not
  /// populate _userLocation.
  Future<LatLng?> _getCurrentLocation() async {
    try {
      final location = Location();
      if (!await location.serviceEnabled()) {
        await location.requestService();
        if (!await location.serviceEnabled()) return null;
      }
      final permission = await location.requestPermission();
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        return null;
      }
      final data = await location.getLocation().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Location request timed out'),
      );
      if (data.latitude != null && data.longitude != null) {
        return LatLng(data.latitude!, data.longitude!);
      }
    } catch (_) {}
    return null;
  }

  void _startLogging() {
    setState(() {
      _isLogging = true;
    });
  }

  void _stopLogging() {
    setState(() {
      _isLogging = false;
    });
    if (mounted) {
      _showCongratulationModal();
    }
  }

  void _showCongratulationModal() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: const Text(
          'You have finished logging. Would you like to review it now?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final logs = await LogService().getLogs();
              if (mounted) {
                if (logs.isNotEmpty) {
                  final mostRecent = logs.first;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => LogReviewPage(logs: [mostRecent]),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No logs to review yet.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Start Review'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
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
          final user = AuthService().getCurrentUser();
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please sign in to add a log.'),
              ),
            );
            return;
          }
          setState(() => _isUploadingPhoto = true);
          try {
            // Fetch location at photo time; _userLocation can be null even when
            // the map shows the blue dot (myLocationEnabled uses a different path).
            final location = await _getCurrentLocation() ?? _userLocation;
            final result = await _graphQLService.addLogEntry(
              userId: user.id,
              imageUrl: imageUrl,
              reflectionText: '',
              lat: location?.latitude,
              lng: location?.longitude,
              timezoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
            );
            setState(() => _isUploadingPhoto = false);
            if (!mounted) return;
            final log = result['log'] as Map<String, dynamic>?;
            if (log == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to create log entry')),
              );
              return;
            }
            final logEntries =
                (log['logEntries'] as List<dynamic>?) ?? [];
            final lastEntry = logEntries.isNotEmpty
                ? logEntries.last as Map<String, dynamic>
                : null;
            print('lastEntry: $lastEntry');
            final question = lastEntry?['question']?.toString() ?? '';
            final logId = log['id']?.toString() ?? '';
            _showAddLogBottomSheet(
              imageUrl: imageUrl,
              logId: logId,
              question: question,
            );
          } catch (e) {
            setState(() => _isUploadingPhoto = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to create log entry: $e')),
              );
            }
          }
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

  Future<void> _showAddLogBottomSheet({
    required String imageUrl,
    required String logId,
    required String question,
  }) async {
    setState(() => _isAddingLog = false);
    final textController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (question.isNotEmpty) ...[
                        Text(
                          question,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700],
                              ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        'Add your reflection below (optional)',
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
                        onPressed: _isAddingLog
                            ? null
                            : () async {
                                final user =
                                    AuthService().getCurrentUser();
                                if (user == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please sign in to add a log.',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                setSheetState(() => _isAddingLog = true);
                                try {
                                  await _graphQLService.updateLogEntryReflection(
                                    logId: logId,
                                    userId: user.id,
                                    reflectionText:
                                        textController.text.trim(),
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Log entry added',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(
                                    () => _isAddingLog = false,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to add log: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: _isAddingLog
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Confirm'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    // Defer disposal to avoid "disposed ChangeNotifier" during route dismissal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      textController.dispose();
    });
  }

  Widget _buildStartLogUI() {
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
          onPressed: _startLogging,
          child: const Text('Start Logging'),
        ),
      ),
    );
  }

  Widget _buildLoggingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Logging is active',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
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
            onPressed: _stopLogging,
            child: const Text('Stop Logging'),
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
                    target: _userLocation ?? LatLng(0, 0),
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
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 0),
              child: _isLogging ? _buildLoggingUI() : _buildStartLogUI(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
