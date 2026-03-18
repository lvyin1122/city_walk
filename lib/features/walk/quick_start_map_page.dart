import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mambo/features/home/log/log_review_page.dart';
import 'package:mambo/services/auth_service.dart';
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
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isLogging = false;
  bool _isUploadingPhoto = false;
  bool _isAddingLog = false;
  String? _currentLogId;
  final ImagePicker _picker = ImagePicker();
  final GraphQLService _graphQLService = GraphQLService();
  Timer? _locationHistoryTimer;
  final List<LatLng> _pathPoints = [];
  Set<Polyline> _pathPolylines = {};

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _setLocationReady(null);
          return;
        }
      }

      final permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted &&
          permissionGranted != PermissionStatus.grantedLimited) {
        _setLocationReady(null);
        return;
      }

      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Location request timed out'),
      );
      if (locationData.latitude != null && locationData.longitude != null) {
        _setLocationReady(
          LatLng(locationData.latitude!, locationData.longitude!),
        );
        _startLiveLocationUpdates();
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

  void _updatePathPolylines(List<LatLng> newPoints, {bool fitCamera = true}) {
    if (!mounted) return;

    setState(() {
      _pathPoints
        ..clear()
        ..addAll(newPoints);

      final pointsForPolyline = _pathPoints.length >= 2
          ? List<LatLng>.from(_pathPoints)
          // If there's only one point, duplicate it so that a tiny
          // segment is still rendered and the path becomes visible.
          : [_pathPoints.first, _pathPoints.first];

      _pathPolylines = {
        Polyline(
          polylineId: const PolylineId('tracking_path'),
          points: pointsForPolyline,
          color: AppColors.primaryColor,
          width: 5,
          geodesic: true,
          zIndex: 1,
        ),
      };
    });

    if (fitCamera) {
      // Fit camera to the updated path after the frame is rendered.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitMapToPath(_pathPoints);
      });
    }
  }

  void _startLiveLocationUpdates() {
    _locationSubscription?.cancel();
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 2000,
      distanceFilter: 3,
    );
    _locationSubscription = _location.onLocationChanged.listen((locationData) {
      final lat = locationData.latitude;
      final lng = locationData.longitude;
      if (lat == null || lng == null || !mounted) return;
      final latestPoint = LatLng(lat, lng);

      setState(() => _userLocation = latestPoint);

      if (_isLogging) {
        _appendLivePathPoint(latestPoint);
      }
    });
  }

  void _appendLivePathPoint(LatLng point) {
    if (_pathPoints.isNotEmpty) {
      final lastPoint = _pathPoints.last;
      final movedDistance = _distanceInMeters(lastPoint, point);
      if (movedDistance < 3) return;
    }
    final updatedPoints = List<LatLng>.from(_pathPoints)..add(point);
    _updatePathPolylines(updatedPoints, fitCamera: false);
  }

  double _distanceInMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final haversine =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadiusMeters * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  void _fitMapToPath(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;
    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
    } else {
      final bounds = LatLngBounds(
        southwest: LatLng(
          points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b) - 0.002,
          points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b) - 0.002,
        ),
        northeast: LatLng(
          points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b) + 0.002,
          points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b) + 0.002,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
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

  Future<void> _startLogging() async {
    final user = AuthService().getCurrentUser();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录以开始记录')),
        );
      }
      return;
    }
    try {
      final logId = await _graphQLService.startLogTracking(
        userId: user.id,
        timezoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
      if (!mounted) return;
      setState(() {
        _currentLogId = logId;
        _isLogging = true;
        _pathPoints.clear();
        _pathPolylines = {};
      });
      if (_userLocation != null) {
        _appendLivePathPoint(_userLocation!);
      }
      _startLocationTracking();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始记录失败：$e')),
        );
      }
    }
  }

  void _startLocationTracking() {
    _locationHistoryTimer?.cancel();
    // Postpone first location push so session is ready; then push every 10 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentLogId != null) _sendLocationPoint();
    });
    _locationHistoryTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _sendLocationPoint(),
    );
  }

  Future<void> _sendLocationPoint() async {
    if (_currentLogId == null) return;
    final user = AuthService().getCurrentUser();
    if (user == null) return;
    final position = _userLocation ?? await _getCurrentLocation();
    if (position == null) return;
    try {
      final points = await _graphQLService.addLogTrackingPoint(
        logId: _currentLogId!,
        userId: user.id,
        lat: position.latitude,
        lng: position.longitude,
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );
      if (points != null && points.isNotEmpty) {
        _updatePathPolylines(points);
      }
    } catch (e) {
      debugPrint('addLogTrackingPoint error: $e');
    }
  }

  Future<void> _stopLogging() async {
    if (_currentLogId != null) {
      try {
        await _graphQLService.endLogTrackingSession(logId: _currentLogId!);
      } catch (_) {}
    }
    _locationHistoryTimer?.cancel();
    _locationHistoryTimer = null;
    if (mounted) {
      setState(() {
        _currentLogId = null;
        _isLogging = false;
        _pathPoints.clear();
        _pathPolylines = {};
      });
      _showCongratulationModal();
    }
  }

  void _showCongratulationModal() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('恭喜！'),
        content: const Text(
          '记录已完成。是否现在回顾？',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final todayKey =
                  '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LogReviewPage(dateKey: todayKey),
                  ),
                );
              }
            },
            child: const Text('开始回顾'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('稍后再说'),
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
                title: const Text('拍照'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
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
                content: Text('请先登录以添加记录'),
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
              logId: _currentLogId,
              lat: location?.latitude,
              lng: location?.longitude,
              timezoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
            );
            setState(() => _isUploadingPhoto = false);
            if (!mounted) return;
            final log = result['log'] as Map<String, dynamic>?;
            if (log == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('创建记录失败')),
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
            final rawReplies = lastEntry?['quickReplies'];
            final quickReplies = rawReplies is List
                ? (rawReplies)
                    .map((e) => e?.toString() ?? '')
                    .where((s) => s.isNotEmpty)
                    .toList()
                : <String>[];
            _showAddLogBottomSheet(
              imageUrl: imageUrl,
              logId: logId,
              question: question,
              quickReplies: quickReplies,
            );
          } catch (e) {
            setState(() => _isUploadingPhoto = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('创建记录失败：$e')),
              );
            }
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('上传照片失败')),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败：$e')),
        );
      }
    }
  }

  Future<void> _showAddLogBottomSheet({
    required String imageUrl,
    required String logId,
    required String question,
    List<String> quickReplies = const [],
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
                        '记录一个瞬间',
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
                      if (quickReplies.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: quickReplies.map((reply) {
                            return ActionChip(
                              label: Text(reply),
                              onPressed: () {
                                final current = textController.text;
                                final separator =
                                    current.isEmpty ? '' : ' ';
                                textController.text =
                                    '$current$separator$reply';
                                setSheetState(() {});
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: '写下你的想法...',
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
                                          '请先登录以添加记录',
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
                                          '记录已添加',
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
                                          '添加记录失败：$e',
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
                            : const Text('提交'),
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
          child: const Text('开始记录'),
        ),
      ),
    );
  }

  Widget _buildLoggingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '记录中...',
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
            label: Text(_isUploadingPhoto ? '上传中...' : '添加照片'),
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
            child: const Text('停止记录'),
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
                  polylines: _pathPolylines,
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
    _locationHistoryTimer?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
