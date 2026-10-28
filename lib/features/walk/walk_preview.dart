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

  void _showPhotos(WalkStop stop) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Stack(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: stop.photoUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          stop.photoUrls[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.error_outline, color: Colors.red),
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
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStopInfoCard() {
    final stop = _tappedStop;
    if (stop == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '已为你选好全部地点。点击地图上的标记查看详情，不想去的可以取消。',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool isSelected = _selectedIndexes.contains(stop.index);

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 8.0,
          bottom: 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stop.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (stop.photoUrls.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.photo_library),
                    tooltip: '查看照片',
                    onPressed: () => _showPhotos(stop),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                  onPressed: () {
                    setState(() {
                      _tappedStop = null;
                    });
                  },
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    stop.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor:
                          isSelected
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _toggleSelected(stop),
                    child: Text(
                      isSelected ? '已选' : '选择',
                      style: TextStyle(
                        color:
                            isSelected
                                ? Colors.green
                                : Theme.of(context).primaryColor,
                        fontWeight: FreshWeights.light,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('开始步行？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('准备好开始步行了吗？记得穿上舒适的鞋子和带上水！'),
              const SizedBox(height: 16),
              Text(
                '已选地点：${stops.length}',
                style: const TextStyle(fontWeight: FreshWeights.light),
              ),
              const SizedBox(height: 8),
              Text(
                '预计时间：${formatMinutes(_estimatedMinutes())}',
                style: const TextStyle(fontWeight: FreshWeights.light),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('再等一下'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.green),
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
        MaterialPageRoute(
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

  @override
  Widget build(BuildContext context) {
    final walk = widget.walk;
    final initialTarget =
        walk.stops.isNotEmpty
            ? walk.stops.first.position.toLatLng()
            : const LatLng(0, 0);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: true,
            zoomControlsEnabled: false,
            // Keeps fitted content clear of the cards drawn over the map.
            padding: const EdgeInsets.only(top: 190, bottom: 210),
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14,
            ),
            markers: {
              for (final stop in walk.stops)
                Marker(
                  markerId: MarkerId('stop_${stop.index}'),
                  infoWindow: InfoWindow(title: stop.name),
                  position: stop.position.toLatLng(),
                  icon:
                      _selectedIndexes.contains(stop.index)
                          ? BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          )
                          : BitmapDescriptor.defaultMarker,
                  onTap: () {
                    setState(() {
                      _tappedStop = stop;
                    });
                  },
                ),
            },
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _fitToContent();
            },
          ),
          Positioned(
            top: 4,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        walk.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FreshWeights.light,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        walk.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '预计时间：${formatMinutes(_estimatedMinutes())}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.place_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '地点：${_selectedIndexes.length}/${walk.stops.length}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Location and Zoom Controls
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  right: 16,
                  bottom: 200,
                  child: FloatingActionButton(
                    heroTag: 'locationButton',
                    mini: true,
                    tooltip: '回到我的位置',
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
                          tooltip: '放大',
                          backgroundColor: Theme.of(context).cardColor,
                          child: const Icon(Icons.add),
                          onPressed: () {
                            _mapController?.animateCamera(CameraUpdate.zoomIn());
                          },
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          heroTag: 'zoomOut',
                          mini: true,
                          tooltip: '缩小',
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
          // Bottom Buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _buildStopInfoCard(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FloatingActionButton(
                          heroTag: 'backButton',
                          tooltip: '返回',
                          backgroundColor: Theme.of(context).cardColor,
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isStarting ? null : _onStartWalk,
                            child:
                                _isStarting
                                    ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text(
                                      '开始步行',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FreshWeights.light,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
