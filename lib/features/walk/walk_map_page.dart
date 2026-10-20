// The walk data on this page is still raw JSON (`dynamic`). The page is due to
// be rebuilt on the typed models in features/walk/domain; until then the
// dynamic-call lint is switched off for this file only.
// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mambo/features/walk/walk_summary.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/core/map/lat_lng.dart';
import 'package:mambo/core/media/image_compressor.dart';
import 'package:mambo/core/media/photo_picker.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:gal/gal.dart';
import 'package:mambo/services/cloudinary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalkMapPage extends StatefulWidget {
  final String walkId;

  const WalkMapPage({super.key, required this.walkId});

  @override
  State<WalkMapPage> createState() => _WalkMapPageState();
}

class _WalkMapPageState extends State<WalkMapPage> {
  static const _walkInfoSeenKey = 'walk_info_seen';

  /// How close the user must get to a stop for it to count as reached.
  static const double _collectRadiusMeters = 20;

  GoogleMapController? _mapController;
  LatLng? _userLocation;
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  Set<String> _collectedLocations = {};
  Map<String, dynamic>? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _timeSpent = '0:00';
  final GraphQLService _graphQLService = GraphQLService();
  Map<String, dynamic>? _currentTask;
  int _photosFulfilled = 0;
  bool _isLoadingTask = true;
  int _tasksCompleted = 0;
  late double _distanceWalked = 0.0;
  List<LatLng> _userLocationHistory = [];
  Timer? _locationHistoryTimer;
  Set<Polyline> _pathPolylines = {};
  LatLng? _lastRecordedLocation;
  bool _isUploadingPhoto = false;
  bool _isUploadingFavoritePhoto = false;
  Timer? _taskCheckTimer;
  int _timeRemainingSeconds = 0;
  bool _hasShownFiveMinuteWarning = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasShownFinishSuggestion = false;
  Set<int> _backendCollectedLocationIndexes = {};
  List<dynamic> _favoriteLocations = [];
  Map<String, dynamic>? _walkData;
  List<dynamic> _selectedLocations = [];
  bool _isLoadingWalk = true;
  Timer? _walkStatsUpdateTimer;
  int _initialTimeSpent = 0;
  bool _isStopped = false;

  // Custom marker icons
  BitmapDescriptor? _customFavoriteMarker;

  /// Stops tracking and releases the map and audio player. Safe to call more
  /// than once: finishing a walk calls it before the page is disposed.
  void _stopAllTimersAndSubscriptions() {
    if (_isStopped) return;
    _isStopped = true;
    _locationHistoryTimer?.cancel();
    _timer?.cancel();
    _taskCheckTimer?.cancel();
    _walkStatsUpdateTimer?.cancel();
    _stopwatch.stop();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    _audioPlayer.dispose();
    unawaited(
      _location.enableBackgroundMode(enable: false).catchError((Object e) {
        debugPrint('Could not disable background location: $e');
        return false;
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _configureLocationSettings();
    _startLocationTracking();
    _startTimer();
    _fetchWalkData();
    _startLocationHistoryTracking();
    _startTaskCheckTimer();
    _startWalkStatsUpdateTimer();
    _loadCustomMarkers();
    _showWalkInfoOnFirstWalk();
  }

  /// Explains the page the first time the user starts a walk. Later it is
  /// available from the info button.
  Future<void> _showWalkInfoOnFirstWalk() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_walkInfoSeenKey) ?? false) return;
    await prefs.setBool(_walkInfoSeenKey, true);
    // Let the page settle before covering it with a dialog.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) _showWalkInfo();
  }

  Future<void> _configureLocationSettings() async {
    try {
      // Keep receiving positions while the screen is locked.
      await _location.enableBackgroundMode(enable: true);
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 10000, // 10 seconds
        distanceFilter: 10, // 10 meters
      );
    } catch (e) {
      // Without background access the walk still works while the app is open.
      debugPrint('Could not enable background location: $e');
    }
  }

  Future<void> _fetchWalkData() async {
    try {
      final result = await _graphQLService.getWalk(walkId: widget.walkId);
      if (!mounted) return;
      final walk = result['data']['walk'];
      final locationsValue = walk['locations'];
      final locations =
          locationsValue is List ? locationsValue : const <dynamic>[];
      final tasks = (walk['tasks'] as List<dynamic>?) ?? const [];

      // Progress made before the walk was paused or the app was closed.
      // A selected stop with no string name or no usable coordinates is left
      // out so one bad item cannot crash the rest of the walk.
      final selectedLocations = <dynamic>[];
      final collectedNames = <String>{};
      final collectedIndexes = <int>{};
      var skippedSelectedStops = 0;
      for (var i = 0; i < locations.length; i++) {
        final location = locations[i];
        if (location is! Map || location['selected'] != true) continue;
        final name = location['name'];
        if (name is! String ||
            latLngFromJson(location['coordinates']) == null) {
          skippedSelectedStops++;
          continue;
        }
        selectedLocations.add(location);
        if (location['collected'] == true) {
          collectedNames.add(name);
          collectedIndexes.add(i);
        }
      }
      if (skippedSelectedStops > 0) {
        debugPrint('Skipped $skippedSelectedStops selected stops');
      }

      setState(() {
        _walkData = walk;
        _selectedLocations = selectedLocations;
        _collectedLocations = collectedNames;
        _backendCollectedLocationIndexes = collectedIndexes;
        _tasksCompleted =
            tasks.where((task) => task['status'] == 'completed').length;
        // Do not suggest finishing again if every stop was already reached.
        _hasShownFinishSuggestion =
            _selectedLocations.isNotEmpty &&
            collectedNames.length == _selectedLocations.length;
        _isLoadingWalk = false;
      });

      // Restore timer and distance from walk data if they exist
      if (walk['timeSpent'] != null) {
        final timeSpentSeconds = int.tryParse(walk['timeSpent'].toString()) ?? 0;
        _stopwatch.reset();
        _stopwatch.start();

        _timeSpent = formatElapsed(Duration(seconds: timeSpentSeconds));

        // Store the initial time spent to add to the stopwatch
        _initialTimeSpent = timeSpentSeconds;
      }

      if (walk['distanceTraveled'] != null) {
        _distanceWalked = double.tryParse(walk['distanceTraveled'].toString()) ?? 0.0;
      }

      if (walk['favoriteLocations'] != null && walk['favoriteLocations'].isNotEmpty) {
        setState(() {
          _favoriteLocations = walk['favoriteLocations'];
        });
      }

      unawaited(_restoreWalkedPath());

      // Continue the task that was open; ask for a new one when there is none
      // or the last one was already completed.
      final lastTask = tasks.isNotEmpty ? tasks.last : null;
      if (lastTask == null || lastTask['status'] == 'completed') {
        await _fetchTask();
      } else {
        setState(() {
          _currentTask = lastTask;
          _photosFulfilled = (lastTask['photosFulfilled'] as num?)?.toInt() ?? 0;
          _isLoadingTask = false;
          _timeRemainingSeconds = 15 * 60; // 15 minutes in seconds
          _hasShownFiveMinuteWarning = false; // Reset warning flag
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingWalk = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载步行数据失败：$e')));
    }
  }

  /// Draws the path walked before the walk was paused. Purely visual, so a
  /// failure is only logged.
  Future<void> _restoreWalkedPath() async {
    try {
      final result = await _graphQLService.getWalkTracking(
        walkId: widget.walkId,
      );
      final coordinates = result['data']?['walkTracking']?['coordinates'];
      if (coordinates is! List || coordinates.isEmpty || !mounted) return;
      final earlier = <LatLng>[
        for (final c in coordinates)
          if (c['latitude'] is num && c['longitude'] is num)
            LatLng(c['latitude'].toDouble(), c['longitude'].toDouble()),
      ];
      setState(() {
        _userLocationHistory = [...earlier, ..._userLocationHistory];
      });
      _updatePathPolylines();
    } catch (e) {
      debugPrint('Could not restore the walked path: $e');
    }
  }

  Future<void> _updateWalkStats() async {
    try {
      await _graphQLService.updateWalkStats(
        walkId: widget.walkId,
        distanceTraveled: _distanceWalked,
        timeSpent: _stopwatch.elapsed.inSeconds + _initialTimeSpent,
      );
    } catch (e) {
      debugPrint('Failed to update walk stats: $e');
      // Don't show error to user for background updates
    }
  }

  void _startWalkStatsUpdateTimer() {
    _walkStatsUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateWalkStats();
    });
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _customFavoriteMarker = await BitmapDescriptor.asset(
        ImageConfiguration.empty,
        'assets/images/love-always-wins.png',
        width: 32,
      );
    } catch (e) {
      debugPrint('Failed to load custom markers: $e');
      _customFavoriteMarker = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
    }
  }

  void _startLocationTracking() {
    _locationSubscription = _location.onLocationChanged.listen(
      (LocationData locationData) {
        setState(() {
          _userLocation = LatLng(
            locationData.latitude,
            locationData.longitude,
          );
          _checkLocationsInRange();
        });
      },
      onError: (error) {
        debugPrint('Location error: $error');
      },
    );
  }

  void _checkLocationsInRange() {
    if (_userLocation == null) return;

    for (var location in _selectedLocations) {
      final markerPosition = latLngFromJson(
        location is Map ? location['coordinates'] : null,
      );
      if (markerPosition == null) continue;
      final distance = latLngDistanceMeters(_userLocation!, markerPosition);

      if (distance <= _collectRadiusMeters) {
        final name = location['name'];
        if (name is! String) continue;
        _collectedLocations.add(name);
        // Tell the backend once. The index is removed again if the call
        // fails, so the next position update inside the radius retries.
        final originalLocations = _walkData!['locations'] as List<dynamic>;
        final locationIndex = originalLocations.indexWhere(
          (loc) => loc is Map && loc['name'] == location['name'],
        );
        if (locationIndex != -1 &&
            _backendCollectedLocationIndexes.add(locationIndex)) {
          _collectLocationOnBackend(locationIndex);
        }
      }
    }

    // Check if all locations are collected and show finish suggestion popup once
    if (!_hasShownFinishSuggestion &&
        _selectedLocations.isNotEmpty &&
        _collectedLocations.length == _selectedLocations.length) {
      _hasShownFinishSuggestion = true;
      Future.delayed(Duration.zero, () => _showFinishSuggestionDialog());
    }
  }

  String _getEstimatedTime(LatLng destination) {
    if (_userLocation == null) return '未知';

    final distance = latLngDistanceMeters(_userLocation!, destination);
    final minutes = walkingMinutes(distance).round();

    if (minutes < 1) return '不足一分钟';
    return formatMinutes(minutes);
  }

  /// First selected stop with usable coordinates, otherwise the user.
  ///
  /// [CameraPosition.target] cannot be null, so a walk with no parsed stop
  /// and no user fix falls back to the origin.
  LatLng _initialCameraTarget() {
    for (final location in _selectedLocations) {
      if (location is! Map) continue;
      final position = latLngFromJson(location['coordinates']);
      if (position != null) return position;
    }
    return _userLocation ?? const LatLng(0, 0);
  }

  String _estimatedWalkLabel(Map<String, dynamic> location) {
    final destination = latLngFromJson(location['coordinates']);
    if (destination == null) return '未知';
    return _getEstimatedTime(destination);
  }

  Future<void> _fetchTask() async {
    try {
      final result = await _graphQLService.generateTask(walkId: widget.walkId);
      if (!mounted) return;
      setState(() {
        _currentTask = result['data']['generateTaskWithGpt']['task'];
        _isLoadingTask = false;
        _timeRemainingSeconds = 15 * 60; // 15 minutes in seconds
        _hasShownFiveMinuteWarning = false; // Reset warning flag
      });
      if (_currentTask != null) {
        unawaited(_audioPlayer.play(AssetSource('audio/notification.wav')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTask = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载任务失败：$e')));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Picks a photo, keeps a gallery copy when it was just taken, uploads it
  /// and returns its URL. Returns null after telling the user why, or when
  /// the user cancelled.
  Future<String?> _pickAndUploadPhoto() async {
    final PickedPhoto? picked;
    try {
      picked = await pickPhoto(context, _picker);
    } catch (e) {
      debugPrint('Picking a photo failed: $e');
      _showMessage('无法打开相机或相册，请检查权限设置');
      return null;
    }
    if (picked == null) return null;

    if (picked.source == ImageSource.camera) {
      await _saveToGallery(picked.file.path);
    }
    try {
      final compressed = await compressImage(File(picked.file.path));
      final url = await CloudinaryService.uploadImage(compressed);
      if (url == null) _showMessage('照片上传失败，请检查网络后重试');
      return url;
    } catch (e) {
      debugPrint('Preparing the photo failed: $e');
      _showMessage('照片处理失败，请重试');
      return null;
    }
  }

  Future<void> _takePhoto() async {
    if (_isUploadingPhoto) return;
    setState(() {
      _isUploadingPhoto = true;
    });
    try {
      final imageUrl = await _pickAndUploadPhoto();
      if (imageUrl == null) return;

      final resultGql = await _graphQLService.verifyTaskWithGpt(
        walkId: widget.walkId,
        imageUrl: imageUrl,
        latitude: _userLocation?.latitude,
        longitude: _userLocation?.longitude,
      );
      if (!mounted) return;

      final verification = resultGql['data']['verifyTaskWithGpt'];
      final success = verification?['success'] == true;
      unawaited(
        _audioPlayer.play(
          AssetSource(success ? 'audio/success.wav' : 'audio/fail.wav'),
        ),
      );
      // Not awaited: the congratulations dialog may open on top of it.
      unawaited(
        showDialog<void>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(success ? '任务完成' : '任务失败'),
                content: Text(verification?['message']?.toString() ?? ''),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('好的'),
                  ),
                ],
              ),
        ),
      );
      if (!success) return;

      setState(() {
        _photosFulfilled++;
      });
      // Check if task is completed
      final photosRequired = _currentTask?['photosRequired'];
      if (photosRequired != null && _photosFulfilled >= photosRequired) {
        await _showCongratulationsModal();
      }
    } on ApiException catch (e) {
      debugPrint('Task verification failed: ${e.details}');
      _showMessage('照片验证失败：${e.userMessage}');
    } catch (e) {
      debugPrint('Task verification failed: $e');
      _showMessage('照片验证失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  /// Keeps a copy of a freshly taken photo in the system gallery. Failing to
  /// save (for example when gallery access is denied) must not interrupt the
  /// task or surprise flow, so errors are only logged.
  Future<void> _saveToGallery(String path) async {
    try {
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('照片已保存到相册！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on GalException catch (e) {
      debugPrint('Failed to save photo to gallery: $e');
    }
  }

  Future<void> _showCongratulationsModal() async {
    setState(() {
      _tasksCompleted++;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const Icon(Icons.celebration, size: 80, color: Colors.amber),
                const SizedBox(height: 24),
                Text(
                  '恭喜！',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '任务已完成！',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '准备迎接下一个挑战...',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );

    // Reset state and fetch new task
    setState(() {
      _photosFulfilled = 0;
      _isLoadingTask = true;
    });
    await _fetchTask();
  }

  void _startTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeSpent = formatElapsed(
          _stopwatch.elapsed + Duration(seconds: _initialTimeSpent),
        );
      });
    });
  }

  void _startLocationHistoryTracking() {
    _locationHistoryTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      if (_userLocation != null) {
        setState(() {
          if (_lastRecordedLocation != null) {
            _distanceWalked +=
                latLngDistanceMeters(_lastRecordedLocation!, _userLocation!) /
                1000;
          }

          _lastRecordedLocation = _userLocation;

          _userLocationHistory.add(_userLocation!);
          _updatePathPolylines();
        });

        // Send coordinate update to server
        try {
          final user = AuthService().getCurrentUser();
          if (user != null) {
            await _graphQLService.addWalkCoordinate(
              walkId: widget.walkId,
              userId: user.id,
              latitude: _userLocation!.latitude,
              longitude: _userLocation!.longitude,
              timestamp: DateTime.now().toIso8601String(),
            );
          }
        } catch (e) {
          debugPrint('Failed to send coordinate update: $e');
        }
      }
    });
  }

  void _updatePathPolylines() {
    if (_userLocationHistory.length < 2) return;

    setState(() {
      _pathPolylines = {
        Polyline(
          polylineId: const PolylineId('userPath'),
          points: _userLocationHistory,
          color: Colors.blue,
          width: 4,
        ),
      };
    });
  }

  void _showWalkInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '欢迎开始你的步行！',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.place,
                  title: '收集地点',
                  description:
                      '走近标记点，找到后它们会变成绿色！📍',
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.add_a_photo,
                  title: '完成任务',
                  description:
                      '按要求拍摄有趣的照片，发挥创意享受过程！📸',
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.favorite,
                  title: '惊喜地点',
                  description:
                      '点击爱心图标标记让你惊喜的地点！🤩',
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.emoji_emotions,
                  title: '享受旅程',
                  description:
                      '慢慢探索，每个角落都藏着故事！✨',
                ),
                const SizedBox(height: 24),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '知道了！',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.2,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startTaskCheckTimer() {
    // Combined timer that counts down every second and checks for new tasks every 15 minutes
    _taskCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Update countdown
      if (_timeRemainingSeconds > 0) {
        setState(() {
          _timeRemainingSeconds--;
        });

        // Check for 5-minute warning
        if (_timeRemainingSeconds == 300 && !_hasShownFiveMinuteWarning) {
          _showFiveMinuteWarning();
        }
      }

      // Check if it's time to generate a new task (every 15 minutes = 900 seconds)
      if (_timeRemainingSeconds == 0 && _currentTask != null) {
        _checkAndGenerateNewTask();
      }
    });
  }

  void _showFiveMinuteWarning() {
    _hasShownFiveMinuteWarning = true;

    // Play notification sound
    unawaited(_audioPlayer.play(AssetSource('audio/notification.wav')));

    // Show snackbar alert
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '当前任务还剩 5 分钟，之后会换一个新任务',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _checkAndGenerateNewTask() async {
    // Only proceed if current task is not completed
    if (_currentTask != null &&
        _photosFulfilled < (_currentTask?['photosRequired'] ?? 0)) {
      // Show friendly notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '换个新挑战！新任务马上就到…',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Show loading indicator
      setState(() {
        _isLoadingTask = true;
      });

      try {
        // Generate new task
        final result = await _graphQLService.generateTask(
          walkId: widget.walkId,
        );
        if (!mounted) return;

        setState(() {
          _currentTask = result['data']['generateTaskWithGpt']['task'];
          _photosFulfilled = 0; // Reset photos fulfilled for new task
          _isLoadingTask = false;
          _timeRemainingSeconds = 15 * 60; // Reset countdown to 15 minutes
          _hasShownFiveMinuteWarning = false; // Reset warning flag
        });
        if (_currentTask != null) {
          unawaited(_audioPlayer.play(AssetSource('audio/notification.wav')));
        }

        // Show success notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.task_alt, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentTask?['description'] ?? '新任务来了！',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade700,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoadingTask = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '新任务没有取到，稍后会再试一次。',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade700,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingWalk) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_selectedLocations.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('这次漫步没能加载出来', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _isLoadingWalk = true);
                    _fetchWalkData();
                  },
                  child: const Text('重试'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: true,
              zoomControlsEnabled: false,
              zoomGesturesEnabled: true,
              initialCameraPosition: CameraPosition(
                target: _initialCameraTarget(),
                zoom: 12,
              ),
              markers: {
                for (final (index, location) in _selectedLocations.indexed)
                  if (latLngFromJson(
                        location is Map ? location['coordinates'] : null,
                      )
                      case final position?)
                    Marker(
                      markerId: MarkerId('stop_$index'),
                      infoWindow: InfoWindow(title: location['name']),
                      position: position,
                      icon:
                          _collectedLocations.contains(location['name'])
                              ? BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen,
                              )
                              : BitmapDescriptor.defaultMarker,
                      onTap: () {
                        setState(() {
                          _selectedLocation = Map<String, dynamic>.from(
                            location,
                          );
                        });
                      },
                    ),
                ..._favoriteLocations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final favorite = entry.value;
                  final position = latLngFromJson(favorite);
                  if (position == null) return null;
                  return Marker(
                    markerId: MarkerId('favorite_$index'),
                    infoWindow: InfoWindow(
                      title: favorite['name']?.toString() ?? '收藏地点',
                      snippet: favorite['description']?.toString() ?? '',
                    ),
                    position: position,
                    icon:
                        _customFavoriteMarker ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueMagenta,
                        ),
                  );
                }).whereType<Marker>(),
              },
              circles:
                  _userLocation != null
                      ? {
                        Circle(
                          circleId: const CircleId('userLocationCircle'),
                          center: _userLocation!,
                          radius: _collectRadiusMeters,
                          fillColor: Colors.blue.withValues(alpha: 0.2),
                          strokeColor: Colors.blue,
                          strokeWidth: 2,
                        ),
                      }
                      : {},
              polylines: _pathPolylines,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
            Positioned(
              bottom: 200,
              left: 8,
              right: 16,
              child: SafeArea(
                child: Column(
                  children: [
                    // Info Button and Favorites Loading
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                      child: Row(
                        children: [
                          FloatingActionButton(
                            heroTag: 'infoButton',
                            mini: true,
                            backgroundColor: Theme.of(context).cardColor,
                            tooltip: '使用说明',
                            onPressed: _showWalkInfo,
                            child: const Icon(Icons.info_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Column(
                  children: [
                    // Time and Distance Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Time spent
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: Colors.deepPurple,
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      _timeSpent,
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            // Distance walked
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(
                                    Icons.directions_walk,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      formatKilometers(_distanceWalked),
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    // Task Description Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child:
                            _isLoadingTask
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : Column(
                                  children: [
                                    // Countdown Timer
                                    if (_currentTask != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _timeRemainingSeconds <= 300
                                                  ? Colors.red.withValues(alpha: 0.1)
                                                  : Colors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color:
                                                _timeRemainingSeconds <= 300
                                                    ? Colors.red.withValues(alpha: 0.3)
                                                    : Colors.blue.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.timer,
                                              size: 14,
                                              color:
                                                  _timeRemainingSeconds <= 300
                                                      ? Colors.red
                                                      : Colors.blue,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '下个任务倒计时：${_formatCountdownTime()}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    _timeRemainingSeconds <= 300
                                                        ? Colors.red
                                                        : Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_currentTask != null)
                                      const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child:
                                              _isUploadingPhoto
                                                  ? const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.green),
                                                    ),
                                                  )
                                                  : const Icon(
                                                    Icons.task_alt,
                                                    color: Colors.green,
                                                    size: 24,
                                                  ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            _currentTask?['description'] ?? '-',
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.refresh),
                                          onPressed: () async {
                                            setState(() {
                                              _isLoadingTask = true;
                                              _photosFulfilled = 0;
                                            });
                                            await _fetchTask();
                                          },
                                          tooltip: '获取新任务',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (_currentTask?['photosRequired'] != null)
                                      Row(
                                        children: List.generate(
                                          _currentTask?['photosRequired'],
                                          (index) => Expanded(
                                            child: Container(
                                              height: 8,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    index < _photosFulfilled
                                                        ? Colors.blue.shade700
                                                        : Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),

                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(context).cardColor,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      onPressed: _takePhoto,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.add_a_photo, size: 24),
                                          SizedBox(width: 8),
                                          Text('添加任务照片'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    // Location Info Card (when selected)
                    if (_selectedLocation != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 8,
                            bottom: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedLocation!['name'],
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                    ),
                                  ),
                                  if (_selectedLocation!['photoUrls'] != null &&
                                      (_selectedLocation!['photoUrls'] as List)
                                          .isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.photo_library),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder:
                                              (context) => Dialog(
                                                backgroundColor:
                                                    Colors.transparent,
                                                elevation: 0,
                                                child: Stack(
                                                  children: [
                                                    ListView.builder(
                                                      shrinkWrap: true,
                                                      itemCount:
                                                          (_selectedLocation!['photoUrls']
                                                                  as List)
                                                              .length,
                                                      itemBuilder: (
                                                        context,
                                                        index,
                                                      ) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8.0,
                                                              ),
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            child: Image.network(
                                                              _selectedLocation!['photoUrls'][index],
                                                              fit: BoxFit.cover,
                                                              loadingBuilder: (
                                                                context,
                                                                child,
                                                                loadingProgress,
                                                              ) {
                                                                if (loadingProgress ==
                                                                    null) {
                                                                  return child;
                                                                }
                                                                return Center(
                                                                  child: CircularProgressIndicator(
                                                                    value:
                                                                        loadingProgress.expectedTotalBytes !=
                                                                                null
                                                                            ? loadingProgress.cumulativeBytesLoaded /
                                                                                loadingProgress.expectedTotalBytes!
                                                                            : null,
                                                                  ),
                                                                );
                                                              },
                                                              errorBuilder: (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) {
                                                                return const Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .error_outline,
                                                                    color:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.white,
                                                        ),
                                                        onPressed:
                                                            () =>
                                                                Navigator.of(
                                                                  context,
                                                                ).pop(),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                        );
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _selectedLocation = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                _selectedLocation!['description'],
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.directions_walk, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '步行约 ${_estimatedWalkLabel(_selectedLocation!)}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    right: 16,
                    bottom: 200,
                    child: FloatingActionButton(
                      heroTag: 'locationButton',
                      mini: true,
                      backgroundColor: Theme.of(context).cardColor,
                      child: const Icon(Icons.my_location),
                      onPressed: () {
                        if (_userLocation != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(_userLocation!, 15),
                          );
                        }
                      },
                    ),
                  ),
                  if (Theme.of(context).platform == TargetPlatform.iOS)
                    Positioned(
                      right: 16,
                      bottom: 280,
                      child: Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'zoomIn',
                            mini: true,
                            backgroundColor: Theme.of(context).cardColor,
                            child: const Icon(Icons.add),
                            onPressed: () {
                              _mapController?.animateCamera(
                                CameraUpdate.zoomIn(),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            heroTag: 'zoomOut',
                            mini: true,
                            backgroundColor: Theme.of(context).cardColor,
                            child: const Icon(Icons.remove),
                            onPressed: () {
                              _mapController?.animateCamera(
                                CameraUpdate.zoomOut(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Locations collected
                      SizedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place,
                              size: 28,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_collectedLocations.length}/${_selectedLocations.length}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              '地点',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Vertical divider
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      // Tasks completed
                      SizedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.task_alt,
                              size: 28,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_tasksCompleted',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              '任务',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Vertical divider
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      // Favorites count
                      SizedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 28,
                              color:
                                  _favoriteLocations.isNotEmpty
                                      ? Colors.red
                                      : Colors.grey,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_favoriteLocations.length}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              '惊喜',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      FloatingActionButton(
                        heroTag: 'backButton',
                        backgroundColor: Theme.of(context).cardColor,
                        tooltip: '暂停并离开',
                        onPressed: _onBackPressed,
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Heart Button
                      SizedBox(
                        width: 200,
                        child: FloatingActionButton.extended(
                          heroTag: 'heartButton',
                          backgroundColor:
                              _isCurrentLocationFavorited()
                                  ? Colors.red
                                  : Theme.of(context).cardColor,
                          icon:
                              _isUploadingFavoritePhoto
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Icon(
                                    _isCurrentLocationFavorited()
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color:
                                        _isCurrentLocationFavorited()
                                            ? Colors.white
                                            : Colors.black87,
                                  ),
                          label: Text(
                            _isUploadingFavoritePhoto
                                ? '上传中…'
                                : _isCurrentLocationFavorited()
                                ? '已标记惊喜'
                                : '这让我惊喜！',
                            style: TextStyle(
                              color:
                                  _isCurrentLocationFavorited()
                                      ? Colors.white
                                      : Colors.black87,
                            ),
                          ),
                          onPressed: _toggleFavoriteLocation,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Finish Button
                      FloatingActionButton(
                        heroTag: 'finishButton',
                        backgroundColor: Colors.green,
                        tooltip: '结束步行',
                        onPressed: _onFinishPressed,
                        child: const Icon(Icons.check),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopAllTimersAndSubscriptions();
    super.dispose();
  }

  Future<void> _onBackPressed() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) Navigator.of(context).pop();
  }

  Future<void> _onFinishPressed() async {
    final shouldFinish = await _onFinishWalk();
    if (shouldFinish && mounted) _openSummary();
  }

  /// Stops tracking and shows the summary of the walk that was just finished.
  void _openSummary() {
    _stopAllTimersAndSubscriptions();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WalkSummary(walkId: widget.walkId, isNew: true),
      ),
    );
  }

  /// Asks whether to leave. Leaving pauses the walk: it stays in progress on
  /// the backend and the home page offers to continue it.
  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('暂停步行？'),
          content: const Text('进度会保存下来，你可以稍后在首页继续这次步行。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续步行'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('暂停并离开'),
            ),
          ],
        );
      },
    );
    if (shouldPop != true) return false;
    // Save the latest numbers; failures are logged inside.
    await _updateWalkStats();
    return true;
  }

  Future<bool> _onFinishWalk() async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('结束步行？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('确定要结束本次步行吗？'),
              const SizedBox(height: 16),
              Text('总结：', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '• 到达地点：${_collectedLocations.length}/${_selectedLocations.length}',
              ),
              Text('• 完成任务：$_tasksCompleted'),
              Text('• 步行距离：${formatKilometers(_distanceWalked)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续步行'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              onPressed: () async {
                try {
                  // First update the walk status
                  await _graphQLService.updateWalkStatus(
                    walkId: widget.walkId,
                    status: 'completed',
                  );

                  // Then update the walk stats
                  await _graphQLService.updateWalkStats(
                    walkId: widget.walkId,
                    distanceTraveled: _distanceWalked,
                    timeSpent: _stopwatch.elapsed.inSeconds + _initialTimeSpent,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('结束步行失败：$e')),
                    );
                  }
                }
              },
              child: const Text('结束步行'),
            ),
          ],
        );
      },
    );
    return shouldFinish ?? false;
  }

  String _formatCountdownTime() {
    final minutes = _timeRemainingSeconds ~/ 60;
    final seconds = _timeRemainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }



  Future<void> _showFinishSuggestionDialog() async {
    if (!mounted) return;
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('所有地点已收集！'),
          content: const Text(
            '你已经到达所有地点。要现在结束步行吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('结束步行'),
            ),
          ],
        );
      },
    );
    if (shouldFinish == true && mounted) {
      final didFinish = await _onFinishWalk();
      if (didFinish && mounted) _openSummary();
    }
  }

  Future<void> _collectLocationOnBackend(int locationIndex) async {
    try {
      await _graphQLService.collectLocation(
        walkId: widget.walkId,
        locationIndex: locationIndex,
      );
    } catch (e) {
      debugPrint('Failed to collect location on backend: $e');
      _backendCollectedLocationIndexes.remove(locationIndex);
    }
  }

  Future<void> _toggleFavoriteLocation() async {
    if (_isUploadingFavoritePhoto) return;
    final position = _userLocation;
    if (position == null) {
      _showMessage('还没有获取到你的位置，请稍后再试');
      return;
    }

    setState(() {
      _isUploadingFavoritePhoto = true;
    });
    try {
      final photoUrl = await _pickAndUploadPhoto();
      if (photoUrl == null) return;

      final resultGql = await _graphQLService.addFavoriteLocation(
        walkId: widget.walkId,
        latitude: position.latitude,
        longitude: position.longitude,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      setState(() {
        _favoriteLocations =
            resultGql['data']['addFavoriteLocation']['walk']['favoriteLocations'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已添加惊喜地点！'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('Adding a surprise spot failed: $e');
      _showMessage('添加惊喜地点失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFavoritePhoto = false;
        });
      }
    }
  }

  bool _isCurrentLocationFavorited() {
    if (_userLocation == null) return false;

    return _favoriteLocations.any(
      (fav) =>
          (fav['latitude'] - _userLocation!.latitude).abs() < 0.0001 &&
          (fav['longitude'] - _userLocation!.longitude).abs() < 0.0001,
    );
  }
}
