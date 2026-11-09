import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:mambo/app/links.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/core/map/lat_lng.dart';
import 'package:mambo/core/map/navigation_link.dart';
import 'package:mambo/core/media/image_compressor.dart';
import 'package:mambo/core/media/photo_picker.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:mambo/services/cloudinary_service.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../consent/ai_consent.dart';
import '../report/report_dialog.dart';
import 'data/walk_repository.dart';
import 'domain/walk.dart';
import 'session/walk_session.dart';
import 'walk_summary.dart';
import 'widgets/walk_controls.dart';
import 'widgets/walk_dialogs.dart';
import 'widgets/walk_panels.dart';

/// The walk in progress: the map with the chosen stops, the current photo
/// task and the user's route.
///
/// State lives in [WalkSession]; this page only connects it to the location
/// stream, timers, the camera and the backend.
class WalkMapPage extends StatefulWidget {
  const WalkMapPage({super.key, required this.walkId, this.repository});

  final String walkId;
  final WalkRepository? repository;

  @override
  State<WalkMapPage> createState() => _WalkMapPageState();
}

class _WalkMapPageState extends State<WalkMapPage> {
  static const _guideSeenKey = 'walk_info_seen';

  /// How often the route is recorded and progress saved.
  static const _recordEvery = Duration(seconds: 10);

  late final WalkRepository _repository = widget.repository ?? WalkRepository();
  final Location _location = Location();
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audio = AudioPlayer();
  final Stopwatch _stopwatch = Stopwatch();

  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _secondTimer;
  Timer? _recordTimer;
  GoogleMapController? _mapController;
  BitmapDescriptor? _surpriseIcon;

  WalkSession? _session;
  bool _loading = true;
  bool _loadFailed = false;
  bool _loadingTask = false;
  bool _uploadingTaskPhoto = false;
  bool _uploadingSurprise = false;
  bool _stopped = false;
  GeoPoint? _position;
  GeoPoint? _lastGoodFix;
  LocationData? _latestFix;
  WalkStop? _selectedStop;
  String? _locationProblem;
  bool _locationReady = false;
  final Set<int> _collectingStops = {};
  final _mapBoundsKey = GlobalKey();
  final _bottomPanelKey = GlobalKey();
  final _bottomViewportKey = GlobalKey();
  double _mapBottomPadding = 320;
  bool _measuringMapPadding = false;

  @override
  void initState() {
    super.initState();
    unawaited(_configureLocation());
    unawaited(_loadSurpriseIcon());
    unawaited(_load());
    unawaited(_showGuideOnFirstWalk());
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  /// Stops tracking and releases the map and audio player. Safe to call more
  /// than once: finishing a walk calls it before the page is disposed.
  void _stop() {
    if (_stopped) return;
    _stopped = true;
    _secondTimer?.cancel();
    _recordTimer?.cancel();
    _stopwatch.stop();
    unawaited(_locationSubscription?.cancel());
    _mapController?.dispose();
    unawaited(_audio.dispose());
    unawaited(
      _location.enableBackgroundMode(enable: false).catchError((Object e) {
        debugPrint('Could not disable background location: $e');
        return false;
      }),
    );
  }

  // --- setup -------------------------------------------------------------------

  Future<void> _configureLocation() async {
    const timeout = Duration(seconds: 15);
    try {
      var enabled = await _location.serviceEnabled().timeout(timeout);
      if (!mounted || _stopped) return;
      if (!enabled) {
        enabled = await _location.requestService().timeout(timeout);
        if (!mounted || _stopped) return;
      }
      if (!enabled) {
        setState(() => _locationProblem = '手机定位服务未开启，路线暂时不会被记录。');
        return;
      }
      var permission = await _location.hasPermission().timeout(timeout);
      if (!mounted || _stopped) return;
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission().timeout(timeout);
        if (!mounted || _stopped) return;
      }
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        setState(() => _locationProblem =
            '没有定位权限，路线暂时不会被记录。请在系统设置中允许 Mambo 使用定位。');
        return;
      }
      setState(() {
        _locationProblem = null;
        _locationReady = true;
      });
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: _recordEvery.inMilliseconds,
        distanceFilter: 10,
      ).timeout(timeout);
      if (!mounted || _stopped) return;
      _locationSubscription ??= _location.onLocationChanged.listen(
        _onPosition,
        onError: (Object e) => debugPrint('Location error: $e'),
      );
    } catch (e) {
      debugPrint('Could not configure location: $e');
      if (!mounted || _stopped) return;
      setState(() => _locationProblem = '手机定位服务未开启，路线暂时不会被记录。');
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _location.changeNotificationOptions(
          title: '漫步进行中',
          subtitle: '正在记录你的路线，可在应用里暂停或结束',
        ).timeout(timeout);
      } catch (e) {
        debugPrint('Could not configure location notification: $e');
      }
      if (!mounted || _stopped) return;
    }
    try {
      // Keep receiving positions while locked using the foreground service.
      await _location.enableBackgroundMode(
        enable: true,
        requireBackgroundPermission: false,
      ).timeout(timeout);
      if (!mounted || _stopped) {
        unawaited(_location.enableBackgroundMode(enable: false).timeout(timeout)
            .catchError((Object e) {
          debugPrint('Could not stop background location after setup: $e');
          return false;
        }));
      }
    } catch (e) {
      // Without background access the walk still records while open.
      debugPrint('Could not enable background location: $e');
    }
  }

  Future<void> _loadSurpriseIcon() async {
    try {
      final icon = await BitmapDescriptor.asset(
        ImageConfiguration.empty,
        'assets/images/love-always-wins.png',
        width: 32,
      );
      if (mounted) setState(() => _surpriseIcon = icon);
    } catch (e) {
      debugPrint('Failed to load the surprise marker: $e');
    }
  }

  Future<void> _showGuideOnFirstWalk() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_guideSeenKey) ?? false) return;
    await prefs.setBool(_guideSeenKey, true);
    // Let the page settle before covering it with a dialog.
    await Future<void>.delayed(FreshMotion.slow);
    if (mounted) await showWalkGuide(context);
  }

  /// Loads the walk, restores its progress and starts the clocks. Nothing is
  /// sent to the backend before this has succeeded.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final walk = await _repository.getWalk(widget.walkId);
      if (!mounted) return;
      final session = WalkSession.resume(walk);
      setState(() {
        _session = session;
        _loading = false;
        _loadFailed = session.stops.isEmpty;
      });
      if (session.stops.isEmpty) return;
      if (_latestFix case final fix?) _onPosition(fix);
      _startClocks();
      unawaited(_restoreEarlierPath(session));
      if (session.task == null) await _nextTask();
    } catch (e) {
      debugPrint('Loading the walk failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _startClocks() {
    if (_secondTimer != null) return;
    _stopwatch.start();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onSecond());
    _recordTimer = Timer.periodic(_recordEvery, (_) => _onRecord());
  }

  /// Draws the route walked before a pause. Purely visual.
  Future<void> _restoreEarlierPath(WalkSession session) async {
    try {
      final earlier = await _repository.getTrack(widget.walkId);
      if (mounted) setState(() => session.restoreEarlierPath(earlier));
    } catch (e) {
      debugPrint('Could not restore the walked path: $e');
    }
  }

  // --- ticks and positions -----------------------------------------------------

  Duration get _elapsed =>
      _session?.totalElapsed(_stopwatch.elapsed) ?? Duration.zero;

  void _onSecond() {
    if (_session != null && mounted) setState(() {});
  }

  void _onPosition(LocationData data) {
    if (!mounted || _stopped) return;
    final latitude = data.latitude;
    final longitude = data.longitude;
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return;
    }
    final position = GeoPoint(latitude, longitude);
    _latestFix = data;
    setState(() => _position = position);

    final session = _session;
    if (session == null) return;
    final millis = data.time;
    final time =
        millis != null && millis.isFinite && millis.abs() <= 8640000000000000
        ? DateTime.fromMillisecondsSinceEpoch(millis.toInt())
        : null;
    if (!session.acceptFix(position, accuracyMeters: data.accuracy, time: time)) {
      return;
    }
    _lastGoodFix = position;
    session.planRoute(position);
    for (final stop in session.reachStopsNear(
      position,
      accuracyMeters: data.accuracy,
    )) {
      unawaited(_collect(session, stop));
    }
  }

  Future<void> _checkIn(WalkStop stop) async {
    final session = _session;
    if (session == null ||
        !session.canCheckIn(stop, _position) ||
        !session.checkIn(stop)) {
      return;
    }
    setState(() {});
    await _collect(session, stop);
  }

  Future<void> _navigateTo(WalkStop stop) async {
    final opened = await AppLinks.open(
      walkingDirectionsUri(stop.position, platform: Theme.of(context).platform),
    );
    if (!mounted) return;
    if (!opened) _showMessage('无法打开地图应用');
  }

  Future<void> _collect(WalkSession session, WalkStop stop) async {
    _collectingStops.add(stop.index);
    try {
      await _repository.collectStop(widget.walkId, stop.index);
      if (!mounted || _stopped) return;
      setState(() {});
      _showMessage('已到达：${stop.name}');
    } catch (e) {
      // Retried on the next position update inside the radius.
      debugPrint('Collecting a stop failed: $e');
      if (mounted) setState(() => session.unreach(stop));
    } finally {
      _collectingStops.remove(stop.index);
    }
    if (mounted && !_stopped && _collectingStops.isEmpty &&
        session.takeFinishSuggestion()) {
      unawaited(_suggestFinish());
    }
  }

  Future<void> _onRecord() async {
    final session = _session;
    final position = _lastGoodFix;
    if (session == null || !mounted || _stopped) return;
    if (position != null) {
      setState(() => session.recordPathPoint(position));
      final user = AuthService().getCurrentUser();
      if (user != null) {
        try {
          await _repository.recordPosition(widget.walkId, user.id, position);
        } catch (e) {
          debugPrint('Recording the route failed: $e');
        }
      }
    }
    if (!mounted || _stopped) return;
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    final session = _session;
    if (session == null) return;
    try {
      await _repository.saveProgress(widget.walkId, _elapsed, session.distanceKm);
    } catch (e) {
      debugPrint('Saving progress failed: $e');
    }
  }

  // --- tasks -------------------------------------------------------------------

  Future<void> _nextTask() async {
    final session = _session;
    if (session == null || _loadingTask || !mounted || _stopped) return;
    setState(() => _loadingTask = true);
    try {
      final consent = await ensureAiConsent(context);
      if (!mounted || _stopped || !consent) return;
      final task = await _repository.nextTask(widget.walkId);
      if (!mounted || _stopped) return;
      setState(() => session.startTask(task));
      _play('audio/notification.wav');
    } on ApiException catch (e) {
      debugPrint('Getting a task failed: ${e.details}');
      _showMessage('新任务没有取到，稍后会再试一次');
    } catch (e) {
      debugPrint('Getting a task failed: $e');
      _showMessage('新任务没有取到，稍后会再试一次');
    } finally {
      if (mounted) setState(() => _loadingTask = false);
    }
  }

  Future<void> _addTaskPhoto() async {
    final session = _session;
    if (session == null || session.task == null || session.taskDone ||
        _loadingTask || _uploadingTaskPhoto || !mounted || _stopped) {
      return;
    }
    setState(() => _uploadingTaskPhoto = true);
    var fetchNextTask = false;
    try {
      final consent = await ensureAiConsent(context);
      if (!mounted || _stopped || !consent) return;
      final url = await _pickAndUploadPhoto();
      if (url == null || !mounted || _stopped) return;
      final check = await _repository.checkTaskPhoto(widget.walkId, url, at: _position);
      if (!mounted || _stopped) return;
      final completed = session.applyPhotoCheck(check);
      setState(() {});
      _play(check.accepted ? 'audio/success.wav' : 'audio/fail.wav');
      if (!check.accepted) {
        await showPhotoVerdict(context, accepted: false, message: check.message);
      } else if (completed) {
        await showTaskCompleted(context, message: check.message);
        fetchNextTask = true;
      } else {
        _showMessage(check.message.isEmpty ? '这张照片符合任务' : check.message);
      }
    } on ApiException catch (e) {
      debugPrint('Checking the photo failed: ${e.details}');
      _showMessage('照片验证失败：${e.userMessage}');
    } catch (e) {
      debugPrint('Checking the photo failed: $e');
      _showMessage('照片验证失败，请重试');
    } finally {
      if (mounted) setState(() => _uploadingTaskPhoto = false);
    }
    // The photo is done with; the next task has its own loading state, so the
    // photo button must not keep saying it is checking a photo meanwhile.
    if (fetchNextTask && mounted && !_stopped) await _nextTask();
  }

  // --- photos and surprises ------------------------------------------------------

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
    if (!mounted || _stopped || picked == null) return null;
    // The gallery copy runs beside the upload: the system can hold it (for
    // example behind the photo-library prompt) and the walk must not wait.
    if (picked.source == ImageSource.camera) {
      unawaited(_saveToGallery(picked.file.path));
    }
    try {
      final compressed = await compressImage(
        File(picked.file.path),
        maxBytes: 450 * 1024,
      ).timeout(const Duration(seconds: 30));
      if (!mounted || _stopped) return null;
      final url = await CloudinaryService.uploadImage(compressed);
      if (!mounted || _stopped) return null;
      if (url == null) _showMessage('照片上传失败，请检查网络后重试');
      return url;
    } catch (e) {
      debugPrint('Preparing the photo failed: $e');
      _showMessage('照片处理失败，请重试');
      return null;
    }
  }

  /// Keeps a copy of a freshly taken photo in the system gallery. Failing to
  /// save must not interrupt the walk, so errors are only logged.
  Future<void> _saveToGallery(String path) async {
    try {
      await Gal.putImage(path);
      if (!mounted || _stopped) return;
      _showMessage('照片已保存到相册');
    } catch (e) {
      debugPrint('Failed to save photo to gallery: $e');
    }
  }

  Future<void> _addSurprise() async {
    final session = _session;
    final position = _position;
    if (session == null || _uploadingSurprise) return;
    if (position == null) {
      _showMessage('还没有获取到你的位置，请稍后再试');
      return;
    }
    setState(() => _uploadingSurprise = true);
    try {
      final url = await _pickAndUploadPhoto();
      if (!mounted || _stopped || url == null) return;
      final spots = await _repository.addSurprise(widget.walkId, position, url);
      if (!mounted || _stopped) return;
      setState(() => session.surprises = spots);
      _showMessage('已记下这个惊喜地点');
    } on ApiException catch (e) {
      debugPrint('Adding a surprise spot failed: ${e.details}');
      _showMessage('添加惊喜地点失败：${e.userMessage}');
    } catch (e) {
      debugPrint('Adding a surprise spot failed: $e');
      _showMessage('添加惊喜地点失败，请重试');
    } finally {
      if (mounted) setState(() => _uploadingSurprise = false);
    }
  }

  // --- leaving -------------------------------------------------------------------

  Future<void> _pause() async {
    final confirmed = await confirmPause(context);
    if (!mounted || !confirmed) return;
    await _saveProgress();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    final session = _session;
    if (session == null) return;
    final finished = await confirmFinish(
      context,
      summary: [
        '到达地点  ${session.reachedStops.length}/${session.stops.length}',
        '完成任务  ${session.tasksCompleted}',
        '步行距离  ${formatKilometers(session.distanceKm)}',
      ],
      finish: () async {
        try {
          await _repository.finishWalk(widget.walkId, _elapsed, session.distanceKm);
          return true;
        } on ApiException catch (e) {
          debugPrint('Finishing failed: ${e.details}');
          _showMessage('结束步行失败：${e.userMessage}');
          return false;
        } catch (e) {
          debugPrint('Finishing failed: $e');
          _showMessage('结束步行失败，请重试');
          return false;
        }
      },
    );
    if (finished && mounted) _openSummary();
  }

  Future<void> _suggestFinish() async {
    if (await suggestFinish(context) && mounted) await _finish();
  }

  void _openSummary() {
    _stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => WalkSummary(walkId: widget.walkId, isNew: true),
      ),
    );
  }

  // --- helpers -------------------------------------------------------------------

  void _play(String asset) => unawaited(
    _audio.play(AssetSource(asset)).catchError((Object e) {
      debugPrint('Sound failed: $e');
    }),
  );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _walkingTimeTo(GeoPoint destination) {
    final position = _position;
    if (position == null) return '未知';
    final minutes = walkingMinutes(distanceMeters(position, destination)).round();
    return minutes < 1 ? '不足一分钟' : formatMinutes(minutes);
  }

  void _moveCamera(CameraUpdate update) =>
      unawaited(_mapController?.animateCamera(update));

  /// Keeps native map attribution above the visible opaque controls, including
  /// the action bar and safe area below them. Runs after size/scroll changes.
  void _scheduleMapPadding() {
    if (_measuringMapPadding) return;
    _measuringMapPadding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuringMapPadding = false;
      if (!mounted || _stopped) return;
      final map = _mapBoundsKey.currentContext?.findRenderObject();
      final panel = _bottomPanelKey.currentContext?.findRenderObject();
      final viewport = _bottomViewportKey.currentContext?.findRenderObject();
      if (map is! RenderBox || panel is! RenderBox || viewport is! RenderBox ||
          !map.attached || !panel.attached || !viewport.attached ||
          !map.hasSize || !panel.hasSize || !viewport.hasSize) {
        return;
      }
      final panelTop = panel.localToGlobal(Offset.zero).dy;
      final viewportTop = viewport.localToGlobal(Offset.zero).dy;
      final mapBottom = map.localToGlobal(Offset.zero).dy + map.size.height;
      final visibleTop = math.max(panelTop, viewportTop);
      final padding = math.max(320.0, mapBottom - visibleTop + FreshSpace.sm);
      if ((_mapBottomPadding - padding).abs() > 0.5) {
        setState(() => _mapBottomPadding = padding);
      }
    });
  }

  // --- build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.2)),
      );
    }
    if (_loadFailed || session == null) return _LoadFailed(onRetry: _load);

    final next = session.nextStop;
    _scheduleMapPadding();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_pause());
      },
      child: Scaffold(
        body: Stack(
          key: _mapBoundsKey,
          children: [
            _map(session),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(FreshSpace.md),
                child: Column(
                  children: [
                    MapPanel(
                      child: Row(
                        children: [
                          Expanded(
                            child: WalkStatsLine(
                              elapsed: _elapsed,
                              distanceKm: session.distanceKm,
                              stops:
                                  '${session.reachedStops.length}/${session.stops.length}',
                            ),
                          ),
                          MapButton(
                            icon: Icons.info_outline,
                            tooltip: '使用说明',
                            onPressed: () => showWalkGuide(context),
                          ),
                        ],
                      ),
                    ),
                    if (_locationProblem != null || _selectedStop != null)
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_locationProblem case final problem?) ...[
                                const SizedBox(height: FreshSpace.sm),
                                LocationNotice(
                                  message: problem,
                                  actionLabel: '重试',
                                  onAction: _configureLocation,
                                ),
                              ],
                              if (_selectedStop case final stop?) ...[
                                const SizedBox(height: FreshSpace.sm),
                                MapPanel(
                                  child: StopDetail(
                                    stop: stop,
                                    reached: session.isReached(stop),
                                    walkingTime: _walkingTimeTo(stop.position),
                                    onShowPhotos: () =>
                                        showStopPhotos(context, stop.photoUrls),
                                    onClose: () =>
                                        setState(() => _selectedStop = null),
                                    onReport: () => showReportDialog(
                                      context,
                                      kind: ReportKind.place,
                                      walkId: widget.walkId,
                                      stopIndex: stop.index,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    // Leave empty map space interactive while controls fit;
                    // scroll only the panels on small screens or large text.
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                          ),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (_) {
                              _scheduleMapPadding();
                              return false;
                            },
                            child: SingleChildScrollView(
                              key: _bottomViewportKey,
                              reverse: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: FreshSpace.sm),
                                  _mapButtons(),
                                  const SizedBox(height: FreshSpace.md),
                                  NotificationListener<
                                    SizeChangedLayoutNotification
                                  >(
                                    onNotification: (_) {
                                      _scheduleMapPadding();
                                      return false;
                                    },
                                    child: SizeChangedLayoutNotifier(
                                      child: MapPanel(
                                        key: _bottomPanelKey,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            NextStopCard(
                                              stop: next,
                                              number: next == null
                                                  ? null
                                                  : session.numberOf(next),
                                              distanceMeters:
                                                  next == null ||
                                                      _position == null
                                                  ? null
                                                  : distanceMeters(
                                                      _position!,
                                                      next.position,
                                                    ),
                                              canCheckIn:
                                                  next != null &&
                                                  session.canCheckIn(
                                                    next,
                                                    _position,
                                                  ),
                                              onNavigate: next == null
                                                  ? null
                                                  : () => _navigateTo(next),
                                              onCheckIn: next == null
                                                  ? null
                                                  : () => _checkIn(next),
                                            ),
                                            const Divider(),
                                            TaskCard(
                                              task: session.taskDone
                                                  ? null
                                                  : session.task,
                                              loading:
                                                  _loadingTask ||
                                                  _uploadingTaskPhoto,
                                              uploading: _uploadingTaskPhoto,
                                              photosFulfilled:
                                                  session.photosFulfilled,
                                              onAddPhoto: _addTaskPhoto,
                                              onNewTask: _nextTask,
                                              onReport: session.task == null
                                                  ? null
                                                  : () => showReportDialog(
                                                      context,
                                                      kind: ReportKind.task,
                                                      walkId: widget.walkId,
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: FreshSpace.sm),
                    WalkActionBar(
                      surpriseMarked: session.hasSurpriseNear(_position),
                      uploadingSurprise: _uploadingSurprise,
                      onPause: _pause,
                      onSurprise: _addSurprise,
                      onFinish: _finish,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _map(WalkSession session) {
    final position = _position;
    return GoogleMap(
      padding: EdgeInsets.only(top: 72, bottom: _mapBottomPadding),
      myLocationEnabled: _locationReady && _locationProblem == null,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: (session.firstStopPosition ?? position ?? const GeoPoint(0, 0)).toLatLng(),
        zoom: 15,
      ),
      markers: {
        for (final stop in session.stops)
          Marker(
            markerId: MarkerId('stop_${stop.index}'),
            position: stop.position.toLatLng(),
            infoWindow: InfoWindow(title: session.routePlanned
              ? '${session.numberOf(stop)}. ${stop.name}' : stop.name),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              session.isReached(stop) ? _MarkerHues.mint : _MarkerHues.sky,
            ),
            onTap: () => setState(() => _selectedStop = stop),
          ),
        for (final (i, spot) in session.surprises.indexed)
          Marker(
            markerId: MarkerId('surprise_$i'),
            position: spot.position.toLatLng(),
            infoWindow: const InfoWindow(title: '惊喜地点'),
            icon: _surpriseIcon ?? BitmapDescriptor.defaultMarkerWithHue(_MarkerHues.pink),
          ),
      },
      circles: {
        if (position != null)
          Circle(
            circleId: const CircleId('reach'),
            center: position.toLatLng(),
            radius: WalkSession.reachRadiusMeters,
            fillColor: FreshColors.sky.withValues(alpha: 0.12),
            strokeColor: FreshColors.sky.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
      },
      polylines: {
        if (session.path.length > 1)
          Polyline(
            polylineId: const PolylineId('route'),
            points: [for (final p in session.path) p.toLatLng()],
            color: FreshColors.sky,
            width: 3,
          ),
      },
      onMapCreated: (controller) => _mapController = controller,
    );
  }

  Widget _mapButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (Theme.of(context).platform == TargetPlatform.iOS) ...[
          MapButton(icon: Icons.add, tooltip: '放大', onPressed: () => _moveCamera(CameraUpdate.zoomIn())),
          const SizedBox(width: FreshSpace.sm),
          MapButton(icon: Icons.remove, tooltip: '缩小', onPressed: () => _moveCamera(CameraUpdate.zoomOut())),
          const SizedBox(width: FreshSpace.sm),
        ],
        MapButton(
          icon: Icons.my_location,
          tooltip: '回到我的位置',
          onPressed: () {
            final position = _position;
            if (position != null) {
              _moveCamera(CameraUpdate.newLatLngZoom(position.toLatLng(), 16));
            }
          },
        ),
      ],
    );
  }
}

/// Marker hues closest to the palette (the map SDK only tints its pin).
abstract final class _MarkerHues {
  static const double sky = 207;
  static const double mint = 165;
  static const double pink = 350;
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(FreshSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('这次漫步没能加载出来', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: FreshSpace.lg),
              ElevatedButton(onPressed: onRetry, child: const Text('重试')),
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
}
