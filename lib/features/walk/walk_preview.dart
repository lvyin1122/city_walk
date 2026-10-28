import 'package:mambo/theme/tokens.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:mambo/core/format/formatters.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/core/map/lat_lng.dart';
import 'package:mambo/features/walk/data/walk_repository.dart';
import 'package:mambo/features/walk/domain/walk.dart';
import 'package:mambo/features/walk/walk_map_page.dart';
import 'package:mambo/features/walk/widgets/walk_dialogs.dart';
import 'package:mambo/features/walk/widgets/walk_panels.dart';
import 'package:mambo/widgets/botanical.dart';

/// Minutes assumed to be spent at each stop when estimating a walk.
const int minutesPerStop = 10;

/// Estimates the minutes needed to visit [stops] in order, starting from
/// [origin]: walking time between them plus [minutesPerStop] at each.
int estimateWalkMinutes(GeoPoint origin, List<WalkStop> stops) {
  if (stops.isEmpty) return 0;
  final path = [origin, for (final stop in stops) stop.position];
  final walking = walkingMinutes(pathLengthMeters(path));
  return (walking + stops.length * minutesPerStop).round();
}

/// Shows a generated walk on the map and lets the user drop the stops they
/// do not want before starting.
class WalkPreviewPage extends StatefulWidget {
  final Walk walk;

  const WalkPreviewPage({super.key, required this.walk});

  @override
  State<WalkPreviewPage> createState() => _WalkPreviewPageState();
}

class _WalkPreviewPageState extends State<WalkPreviewPage> {
  final WalkRepository _repository = WalkRepository();
  final Location _location = Location();
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  StreamSubscription<LocationData>? _locationSubscription;
  WalkStop? _tappedStop;
  bool _hasFittedWithUser = false;
  bool _isStarting = false;

  /// Indexes of the stops the user will visit. Every stop starts selected;
  /// the user removes the ones they do not want.
  late final Set<int> _selectedIndexes = {
    for (final stop in widget.walk.stops) stop.index,
  };

  List<WalkStop> get _selectedStops =>
      widget.walk.stops
          .where((stop) => _selectedIndexes.contains(stop.index))
          .toList();

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  void _startLocationTracking() {
    _locationSubscription = _location.onLocationChanged.listen((
      LocationData locationData,
    ) {
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(locationData.latitude, locationData.longitude);
      });

      // Include the user in the view once their position is known.
      if (!_hasFittedWithUser) {
        _hasFittedWithUser = true;
        _fitToContent();
      }
    }, onError: (Object error) => debugPrint('Location error: $error'));
  }

  /// Moves the camera so that every stop, and the user when known, is visible.
  void _fitToContent() {
    final update = cameraUpdateToFit([
      for (final stop in widget.walk.stops) stop.position.toLatLng(),
      ?_userLocation,
    ]);
    if (update == null) return;
    // The map needs a laid-out size before it can fit bounds.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _mapController?.animateCamera(update);
      } catch (e) {
        debugPrint('Could not fit the map to the walk: $e');
      }
    });
  }

  int _estimatedMinutes() {
    final origin = _userLocation?.toGeoPoint();
    final stops = _selectedStops;
    if (stops.isEmpty) return 0;
    // Without a known position, start the estimate at the first stop.
    return estimateWalkMinutes(origin ?? stops.first.position, stops);
  }

  void _toggleSelected(WalkStop stop) {
    setState(() {
      if (!_selectedIndexes.remove(stop.index)) {
        _selectedIndexes.add(stop.index);
      }
    });
  }

  Widget _buildStopInfo() {
    final text = Theme.of(context).textTheme;
    final stop = _tappedStop;
    if (stop == null) {
      return Row(
        children: [
          const Icon(Icons.touch_app_outlined, size: 20, color: FreshColors.inkSoft),
          const SizedBox(width: FreshSpace.md),
          Expanded(
            child: Text(
              '已为你选好全部地点。点击地图上的标记查看详情，不想去的可以取消。',
              style: text.bodySmall,
            ),
          ),
        ],
      );
    }

    final isSelected = _selectedIndexes.contains(stop.index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(stop.name, style: text.titleMedium)),
            if (stop.photoUrls.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                tooltip: '查看照片',
                onPressed: () => showStopPhotos(context, stop.photoUrls),
              ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '关闭',
              onPressed: () => setState(() => _tappedStop = null),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                stop.description,
                style: text.bodySmall,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: FreshSpace.md),
            FilterChip(
              label: Text(isSelected ? '已选' : '选择'),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => _toggleSelected(stop),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onStartWalk() async {
    if (_isStarting) return;
    final stops = _selectedStops;
    if (stops.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一个地点')));
      return;
    }

    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) {
        final text = Theme.of(context).textTheme;
        return AlertDialog(
          icon: const Botanical(kind: BotanicalKind.sprig, size: 52),
          title: const Text('开始步行？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('准备好开始步行了吗？记得穿上舒适的鞋子和带上水！'),
              const SizedBox(height: FreshSpace.md),
              Text('已选地点：${stops.length}', style: text.bodyLarge),
              const SizedBox(height: FreshSpace.xs),
              Text('预计时间：${formatMinutes(_estimatedMinutes())}', style: text.bodyLarge),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('再等一下'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('出发！'),
            ),
          ],
        );
      },
    );

    if (shouldStart != true || !mounted) return;

    setState(() => _isStarting = true);
    try {
      await _repository.startWalk(widget.walk.id, [
        for (final stop in stops) stop.index,
      ]);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => WalkMapPage(walkId: widget.walk.id),
        ),
      );
      // Coming back means the walk was paused: return to the home page,
      // which offers to resume it.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('开始步行失败：$e')));
    }
  }

  void _moveCamera(CameraUpdate update) =>
      unawaited(_mapController?.animateCamera(update));

  @override
  Widget build(BuildContext context) {
    final walk = widget.walk;
    final text = Theme.of(context).textTheme;
    final initialTarget =
        walk.stops.isNotEmpty ? walk.stops.first.position.toLatLng() : const LatLng(0, 0);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            // Keeps fitted content clear of the panels drawn over the map.
            padding: const EdgeInsets.only(top: 190, bottom: 230),
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
            markers: {
              for (final stop in walk.stops)
                Marker(
                  markerId: MarkerId('stop_${stop.index}'),
                  infoWindow: InfoWindow(title: stop.name),
                  position: stop.position.toLatLng(),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    _selectedIndexes.contains(stop.index) ? 207 : 40,
                  ),
                  alpha: _selectedIndexes.contains(stop.index) ? 1 : 0.55,
                  onTap: () => setState(() => _tappedStop = stop),
                ),
            },
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _fitToContent();
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(FreshSpace.md),
              child: Column(
                children: [
                  MapPanel(
                    padding: const EdgeInsets.all(FreshSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          walk.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineSmall,
                        ),
                        const SizedBox(height: FreshSpace.xs),
                        Text(
                          walk.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: FreshSpace.md),
                        Wrap(
                          spacing: FreshSpace.lg,
                          runSpacing: FreshSpace.xs,
                          children: [
                            _Fact(Icons.schedule_outlined, '预计时间：${formatMinutes(_estimatedMinutes())}'),
                            _Fact(Icons.place_outlined, '地点：${_selectedIndexes.length}/${walk.stops.length}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
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
                          final position = _userLocation;
                          if (position != null) {
                            _moveCamera(CameraUpdate.newLatLngZoom(position, 15));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: FreshSpace.md),
                  MapPanel(child: _buildStopInfo()),
                  const SizedBox(height: FreshSpace.md),
                  Row(
                    children: [
                      MapButton(
                        icon: Icons.arrow_back,
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: FreshSpace.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isStarting ? null : _onStartWalk,
                          child:
                              _isStarting
                                  ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 1.2),
                                  )
                                  : const Text('开始步行'),
                        ),
                      ),
                    ],
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
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: FreshColors.inkSoft),
        const SizedBox(width: FreshSpace.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
