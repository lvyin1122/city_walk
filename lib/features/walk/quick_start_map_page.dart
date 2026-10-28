import 'package:mambo/features/walk/widgets/walk_panels.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/theme/tokens.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mambo/core/map/lat_lng.dart';
import 'package:mambo/core/media/image_compressor.dart';
import 'package:mambo/core/media/photo_picker.dart';
import 'package:mambo/features/home/log/log_review_page.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:mambo/services/cloudinary_service.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

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
      _setLocationReady(
        LatLng(locationData.latitude, locationData.longitude),
      );
      _startLiveLocationUpdates();
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
          color: FreshColors.sky,
          width: 3,
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
      if (!mounted) return;
      final latestPoint = LatLng(
        locationData.latitude,
        locationData.longitude,
      );

      setState(() => _userLocation = latestPoint);

      if (_isLogging) {
        _appendLivePathPoint(latestPoint);
      }
    });
  }

  void _appendLivePathPoint(LatLng point) {
    if (_pathPoints.isNotEmpty) {
      final lastPoint = _pathPoints.last;
      final movedDistance = latLngDistanceMeters(lastPoint, point);
      if (movedDistance < 3) return;
    }
    final updatedPoints = List<LatLng>.from(_pathPoints)..add(point);
    _updatePathPolylines(updatedPoints, fitCamera: false);
  }

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
      return LatLng(data.latitude, data.longitude);
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
        _updatePathPolylines([for (final point in points) point.toLatLng()]);
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

  Future<void> _takePhoto() async {
    try {
      final result = await pickPhoto(context, _picker);
      if (result != null) {
        final XFile photo = result.file;
        setState(() => _isUploadingPhoto = true);

        final File compressedFile = await compressImage(File(photo.path));
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
            final question = lastEntry?['question']?.toString() ?? '';
            final logId = log['id']?.toString() ?? '';
            final rawReplies = lastEntry?['quickReplies'];
            final quickReplies = rawReplies is List
                ? (rawReplies)
                    .map((e) => e?.toString() ?? '')
                    .where((s) => s.isNotEmpty)
                    .toList()
                : <String>[];
            unawaited(
              _showAddLogBottomSheet(
                imageUrl: imageUrl,
                logId: logId,
                question: question,
                quickReplies: quickReplies,
              ),
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
                      Text('记录一个瞬间', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: FreshSpace.lg),
                      ClipRRect(
                        borderRadius: FreshRadius.button,
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
                          style: Theme.of(context).textTheme.bodyLarge,
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
                        decoration: const InputDecoration(
                          labelText: '写下你的想法…',
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
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
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 1.2),
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
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('没有路线，只是随意走走', style: text.titleMedium)),
            const Botanical(kind: BotanicalKind.bamboo, size: 48),
          ],
        ),
        const SizedBox(height: FreshSpace.xs),
        Text('开始后会记录你的足迹，可以随时拍下一个瞬间。', style: text.bodySmall),
        const SizedBox(height: FreshSpace.lg),
        ElevatedButton(onPressed: _startLogging, child: const Text('开始记录')),
      ],
    );
  }

  Widget _buildLoggingUI() {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.fiber_manual_record, size: 10, color: FreshColors.mintText),
            const SizedBox(width: FreshSpace.sm),
            Text('记录中…', style: text.titleMedium),
          ],
        ),
        const SizedBox(height: FreshSpace.lg),
        OutlinedButton.icon(
          onPressed: _isUploadingPhoto ? null : _takePhoto,
          icon:
              _isUploadingPhoto
                  ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.2),
                  )
                  : const Icon(Icons.photo_camera_outlined, size: 20),
          label: Text(_isUploadingPhoto ? '上传中…' : '添加照片'),
        ),
        const SizedBox(height: FreshSpace.md),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: FreshColors.error),
          onPressed: _stopLogging,
          child: const Text('停止记录'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            polylines: _pathPolylines,
            padding: const EdgeInsets.only(bottom: 260),
            initialCameraPosition: CameraPosition(
              target: _userLocation ?? const LatLng(0, 0),
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              final position = _userLocation;
              if (position != null) {
                controller.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
              }
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(FreshSpace.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      MapButton(
                        icon: Icons.arrow_back,
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      MapButton(
                        icon: Icons.my_location,
                        tooltip: '回到我的位置',
                        onPressed: () {
                          final position = _userLocation;
                          if (position != null) {
                            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
                          }
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  MapPanel(
                    padding: const EdgeInsets.all(FreshSpace.lg),
                    child: AnimatedSwitcher(
                      duration: FreshMotion.of(context),
                      child: _isLogging ? _buildLoggingUI() : _buildStartLogUI(),
                    ),
                  ),
                ],
              ),
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
