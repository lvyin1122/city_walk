import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/core/map/lat_lng.dart';
import 'package:mambo/features/walk/data/walk_repository.dart';
import 'package:mambo/features/walk/domain/walk.dart';

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

  void _showImagePopup(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final walk = _walk;
    return PopScope(
      canPop: !widget.isNew,
      child: Scaffold(
        body: SafeArea(
          child:
              walk != null
                  ? _buildContent(context, walk)
                  : _loadError != null
                  ? _buildLoadError(_loadError!)
                  : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildLoadError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
            TextButton(
              onPressed: _leave,
              child: Text(widget.isNew ? '返回首页' : '返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Walk walk) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(context, walk),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStats(context, walk),
                const SizedBox(height: 24),
                _buildMap(walk),
                const SizedBox(height: 24),
                _buildStory(context),
                const SizedBox(height: 24),
                _PhotoSection(
                  title: '心动瞬间 💖',
                  photoUrls: [
                    for (final surprise in _surprises)
                      if (surprise.photoUrl.isNotEmpty) surprise.photoUrl,
                  ],
                  onTap: _showImagePopup,
                ),
                const SizedBox(height: 24),
                _PhotoSection(
                  title: '任务照片 📝',
                  photoUrls: _taskPhotoUrls,
                  onTap: _showImagePopup,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _leave,
                    child: Text(
                      widget.isNew ? '返回首页' : '返回',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Walk walk) {
    final textTheme = Theme.of(context).textTheme;
    if (widget.isNew) {
      return Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.celebration, size: 40, color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            '恭喜！',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('你已完成本次步行', style: textTheme.titleMedium),
          const SizedBox(height: 24),
        ],
      );
    }

    final address = formatUserAddress(walk.userAddress);
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _leave,
            tooltip: '返回',
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  walk.title.isNotEmpty ? walk.title : '漫步总结',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatDayOfWeek(walk.createdAt)}  '
                  '${formatMonthDay(walk.createdAt)}  '
                  '${formatTimeOfDay(walk.createdAt)}',
                  style: textTheme.bodyMedium,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(address, style: textTheme.bodyMedium),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context, Walk walk) {
    final timeSpent = walk.timeSpent;
    final planned = walk.plannedMinutes;
    final distance = walk.distanceKm;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            _StatRow(
              icon: Icons.place,
              color: Colors.blue,
              label: '地点',
              value:
                  '${walk.collectedStops.length}/${walk.selectedStops.length}',
            ),
            const Divider(),
            _StatRow(
              icon: Icons.task_alt,
              color: Colors.green,
              label: '任务',
              value: '${walk.completedTaskCount}',
            ),
            const Divider(),
            _StatRow(
              icon: Icons.timer,
              color: Colors.purple,
              label: '时长',
              value:
                  timeSpent != null
                      ? formatElapsed(timeSpent)
                      : planned != null
                      ? formatMinutes(planned)
                      : '--',
            ),
            const Divider(),
            _StatRow(
              icon: Icons.directions_walk,
              color: Colors.orange,
              label: '距离',
              value: distance != null ? formatKilometers(distance) : '--',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(Walk walk) {
    final stops = walk.selectedStops;
    final points = _mapPoints;

    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                // Green for a stop that was reached.
                icon:
                    stop.collected
                        ? BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        )
                        : BitmapDescriptor.defaultMarker,
              ),
            for (final (index, surprise) in _surprises.indexed)
              Marker(
                markerId: MarkerId('surprise_$index'),
                infoWindow: const InfoWindow(title: '惊喜地点'),
                position: surprise.position.toLatLng(),
                icon:
                    _surpriseMarker ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
              ),
          },
          polylines: {
            if (_track.length >= 2)
              Polyline(
                polylineId: const PolylineId('userPath'),
                points: [for (final point in _track) point.toLatLng()],
                color: Colors.blue,
                width: 4,
              ),
          },
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _fitMapToContent();
          },
        ),
      ),
    );
  }

  Widget _buildStory(BuildContext context) {
    final story = _story;

    final Widget body;
    if (_storyFailed) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('故事暂时没有写出来。'),
          TextButton(onPressed: _loadStory, child: const Text('再试一次')),
        ],
      );
    } else if (story == null) {
      body = const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('正在为你写下这次步行的故事…')),
        ],
      );
    } else {
      body = Text(
        story.isNotEmpty ? story : '这次步行还没有故事。',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '你的步行故事',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Text(label, style: textTheme.titleMedium),
          const Spacer(),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// A titled grid of photo thumbnails that open full size when tapped.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.title,
    required this.photoUrls,
    required this.onTap,
  });

  final String title;
  final List<String> photoUrls;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (photoUrls.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '本次步行暂无照片',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: photoUrls.length,
            itemBuilder: (context, index) {
              final url = photoUrls[index];
              return GestureDetector(
                onTap: () => onTap(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return ColoredBox(color: Colors.grey.shade200);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
