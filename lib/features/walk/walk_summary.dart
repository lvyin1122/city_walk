import 'package:mambo/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/core/map/lat_lng.dart';
import 'package:mambo/features/walk/data/walk_repository.dart';
import 'package:mambo/features/walk/domain/walk.dart';
import 'package:mambo/features/walk/widgets/summary_sections.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';

/// Summary of one walk: numbers, map, the AI-written story and photos.
///
/// [isNew] is true right after finishing a walk. The page then congratulates
/// the user and can only be left through "back to home". From the history it
/// is an ordinary page that can be popped.
class WalkSummary extends StatefulWidget {
  final String walkId;
  final bool isNew;

  const WalkSummary({super.key, required this.walkId, required this.isNew});

  @override
  State<WalkSummary> createState() => _WalkSummaryState();
}

class _WalkSummaryState extends State<WalkSummary> {
  final WalkRepository _repository = WalkRepository();
  GoogleMapController? _mapController;
  BitmapDescriptor? _surpriseMarker;

  Walk? _walk;
  String? _loadError;
  List<String> _taskPhotoUrls = [];
  List<SurpriseSpot> _surprises = [];
  List<GeoPoint> _track = [];

  /// The AI-written story. Null while loading; see [_storyFailed].
  String? _story;
  bool _storyFailed = false;

  @override
  void initState() {
    super.initState();
    _loadSurpriseMarker();
    _load();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadSurpriseMarker() async {
    try {
      final marker = await BitmapDescriptor.asset(
        ImageConfiguration.empty,
        'assets/images/love-always-wins.png',
        width: 32,
      );
      if (mounted) setState(() => _surpriseMarker = marker);
    } catch (e) {
      debugPrint('Failed to load the surprise marker: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _walk = null;
      _loadError = null;
    });
    try {
      final walk = await _repository.getWalk(widget.walkId);
      if (!mounted) return;
      setState(() {
        _walk = walk;
        _surprises = walk.surprises;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '加载步行数据失败：$e');
      return;
    }

    // The rest decorates the page; each part may fail without hiding the
    // others.
    await Future.wait([
      _loadPart(
        () => _repository.getTaskPhotoUrls(widget.walkId),
        (urls) => _taskPhotoUrls = urls,
      ),
      _loadPart(
        () => _repository.getSurprises(widget.walkId),
        (surprises) => _surprises = surprises,
      ),
      _loadPart(
        () => _repository.getTrack(widget.walkId),
        (track) => _track = track,
      ),
      _loadStory(),
    ]);
    _fitMapToContent();
  }

  Future<void> _loadPart<T>(
    Future<T> Function() fetch,
    void Function(T value) store,
  ) async {
    try {
      final value = await fetch();
      if (mounted) setState(() => store(value));
    } catch (e) {
      debugPrint('Could not load part of the walk summary: $e');
    }
  }

  Future<void> _loadStory() async {
    setState(() {
      _story = null;
      _storyFailed = false;
    });
    try {
      final story = await _repository.getSummary(widget.walkId);
      if (mounted) setState(() => _story = story);
    } catch (e) {
      debugPrint('Could not load the walk story: $e');
      if (mounted) setState(() => _storyFailed = true);
    }
  }

  List<LatLng> get _mapPoints => [
    for (final stop in _walk?.selectedStops ?? const <WalkStop>[])
      stop.position.toLatLng(),
    for (final surprise in _surprises) surprise.position.toLatLng(),
    for (final point in _track) point.toLatLng(),
  ];

  void _fitMapToContent() {
    final update = cameraUpdateToFit(_mapPoints);
    if (update == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _mapController?.animateCamera(update);
      } catch (e) {
        debugPrint('Could not fit the summary map: $e');
      }
    });
  }

  void _leave() {
    if (widget.isNew) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final walk = _walk;
    return PopScope(
      canPop: !widget.isNew,
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            child:
                walk != null
                    ? _buildContent(context, walk)
                    : _loadError != null
                    ? _buildLoadError(_loadError!)
                    : const Center(child: CircularProgressIndicator(strokeWidth: 1.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FreshSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: FreshSpace.lg),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
            TextButton(onPressed: _leave, child: Text(widget.isNew ? '返回首页' : '返回')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Walk walk) {
    const gap = SizedBox(height: FreshSpace.xxl);
    return ListView(
      padding: const EdgeInsets.fromLTRB(FreshSpace.page, 0, FreshSpace.page, FreshSpace.xxl),
      children: [
        _buildHeader(context, walk),
        WalkStatsCard(walk: walk),
        gap,
        _buildMap(walk),
        gap,
        WalkStoryCard(story: _story, failed: _storyFailed, onRetry: _loadStory),
        gap,
        PhotoGrid(
          title: '心动瞬间',
          photoUrls: [
            for (final surprise in _surprises)
              if (surprise.photoUrl.isNotEmpty) surprise.photoUrl,
          ],
          onTap: (url) => showPhotoViewer(context, url),
        ),
        gap,
        PhotoGrid(
          title: '任务照片',
          photoUrls: _taskPhotoUrls,
          onTap: (url) => showPhotoViewer(context, url),
        ),
        const SizedBox(height: FreshSpace.section * 0.6),
        widget.isNew
            ? ElevatedButton(onPressed: _leave, child: const Text('返回首页'))
            : OutlinedButton(onPressed: _leave, child: const Text('返回')),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Walk walk) {
    final text = Theme.of(context).textTheme;
    final address = formatUserAddress(walk.userAddress);
    final when =
        '${formatDayOfWeek(walk.createdAt)}  ${formatMonthDay(walk.createdAt)}  ${formatTimeOfDay(walk.createdAt)}';
    return Padding(
      padding: EdgeInsets.only(top: widget.isNew ? FreshSpace.section * 0.6 : FreshSpace.sm, bottom: FreshSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isNew)
            Padding(
              padding: const EdgeInsets.only(bottom: FreshSpace.lg),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _leave,
                tooltip: '返回',
              ),
            ),
          FreshHeading(
            widget.isNew ? '恭喜，你完成了这次漫步' : (walk.title.isNotEmpty ? walk.title : '漫步总结'),
            subtitle: widget.isNew ? walk.title : when,
            botanical: widget.isNew ? BotanicalKind.blossom : BotanicalKind.ginkgo,
          ),
          if (!widget.isNew && address.isNotEmpty) ...[
            const SizedBox(height: FreshSpace.xs),
            Text(address, style: text.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(Walk walk) {
    final stops = walk.selectedStops;
    final points = _mapPoints;

    return Container(
      height: 300,
      decoration: BoxDecoration(borderRadius: FreshRadius.card, border: FreshBorders.all),
      child: ClipRRect(
        borderRadius: FreshRadius.card,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: points.isNotEmpty ? points.first : const LatLng(0, 0),
            zoom: 14,
          ),
          markers: {
            for (final stop in stops)
              Marker(
                markerId: MarkerId('stop_${stop.index}'),
                infoWindow: InfoWindow(title: stop.name),
                position: stop.position.toLatLng(),
                // Mint for a stop that was reached, sky blue otherwise.
                icon: BitmapDescriptor.defaultMarkerWithHue(stop.collected ? 165 : 207),
              ),
            for (final (index, surprise) in _surprises.indexed)
              Marker(
                markerId: MarkerId('surprise_$index'),
                infoWindow: const InfoWindow(title: '惊喜地点'),
                position: surprise.position.toLatLng(),
                icon: _surpriseMarker ?? BitmapDescriptor.defaultMarkerWithHue(350),
              ),
          },
          polylines: {
            if (_track.length >= 2)
              Polyline(
                polylineId: const PolylineId('userPath'),
                points: [for (final point in _track) point.toLatLng()],
                color: FreshColors.sky,
                width: 3,
              ),
          },
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _fitMapToContent();
          },
        ),
      ),
    );
  }
}
