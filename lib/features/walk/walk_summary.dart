import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/services/graphql_service.dart';
import 'dart:math';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import '../home/walk_history/utils.dart';

class WalkSummary extends StatefulWidget {
  final String walkId;
  final bool isNew;

  const WalkSummary({super.key, required this.walkId, required this.isNew});

  @override
  State<WalkSummary> createState() => _WalkSummaryState();
}

class _WalkSummaryState extends State<WalkSummary> {
  final GraphQLService _graphQLService = GraphQLService();
  Map<String, dynamic>? _walkData;
  List<String> _imageUrls = [];
  List<dynamic> _surprisingLocationImages = [];
  bool _isLoading = true;
  Set<Polyline> _pathPolylines = {};
  GoogleMapController? _mapController;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;
  final GlobalKey _contentKey = GlobalKey();
  String? _walkSummary;
  BitmapDescriptor? _customFavoriteMarker;
  List<LatLng> _trackingPoints = [];

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _fetchAllWalkData();
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _customFavoriteMarker = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(1, 1)),
        'assets/images/love-always-wins.png',
      );
    } catch (e) {
      print('Failed to load custom markers: $e');
      _customFavoriteMarker = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
    }
  }

  Future<void> _fetchAllWalkData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final walkResult = await _graphQLService.getWalk(walkId: widget.walkId);
      final walk = walkResult['data']['walk'];
      setState(() {
        _walkData = walk;
      });
      await Future.wait([
        _fetchImageUrls(),
        _fetchSurprisingLocationImages(),
        _fetchWalkSummary(),
        _fetchWalkTracking(),
      ]);
      _updatePathPolylines();
      if (_mapController != null) {
        _fitBounds();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load walk data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchWalkTracking() async {
    try {
      final result = await _graphQLService.getWalkTracking(
        walkId: widget.walkId,
      );
      final List<dynamic> coords =
          result['data']['walkTracking']['coordinates'];
      setState(() {
        _trackingPoints =
            coords
                .map<LatLng>((c) => LatLng(c['latitude'], c['longitude']))
                .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load walk tracking: $e')),
        );
      }
    }
  }

  void _updatePathPolylines() {
    if (_trackingPoints.isEmpty) return;
    setState(() {
      _pathPolylines = {
        Polyline(
          polylineId: const PolylineId('userPath'),
          points: _trackingPoints,
          color: Colors.blue,
          width: 4,
        ),
      };
    });
  }

  LatLng _getMapCenter() {
    if (_walkData == null ||
        _walkData!['locations'] == null ||
        _walkData!['locations'].isEmpty) {
      return const LatLng(0, 0);
    }
    final locations = _walkData!['locations'];
    final first = locations.first['coordinates'];
    final last = locations.last['coordinates'];
    return LatLng(
      (first['latitude'] + last['latitude']) / 2,
      (first['longitude'] + last['longitude']) / 2,
    );
  }

  LatLngBounds _getBounds() {
    if (_walkData == null ||
        _walkData!['locations'] == null ||
        _walkData!['locations'].isEmpty) {
      return LatLngBounds(southwest: LatLng(0, 0), northeast: LatLng(0, 0));
    }
    final selectedLocations = _walkData!['locations'].where(
      (loc) => loc['selected'] == true,
    );
    if (selectedLocations.isEmpty) {
      return LatLngBounds(southwest: LatLng(0, 0), northeast: LatLng(0, 0));
    }
    double minLat = selectedLocations.first['coordinates']['latitude'];
    double maxLat = minLat;
    double minLng = selectedLocations.first['coordinates']['longitude'];
    double maxLng = minLng;
    for (var location in selectedLocations) {
      final lat = location['coordinates']['latitude'];
      final lng = location['coordinates']['longitude'];
      minLat = min(minLat, lat);
      maxLat = max(maxLat, lat);
      minLng = min(minLng, lng);
      maxLng = max(maxLng, lng);
    }
    for (var favorite in _surprisingLocationImages) {
      final lat = favorite['latitude'];
      final lng = favorite['longitude'];
      minLat = min(minLat, lat);
      maxLat = max(maxLat, lat);
      minLng = min(minLng, lng);
      maxLng = max(maxLng, lng);
    }
    const double padding = 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  void _fitBounds() {
    if (_mapController == null) return;
    final bounds = _getBounds();
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Future<void> _fetchImageUrls() async {
    try {
      final result = await _graphQLService.getAllTasksImages(
        walkId: widget.walkId,
      );
      setState(() {
        _imageUrls = List<String>.from(
          result['data']['getAllTasksImages']['images'].map(
            (image) => image['url'],
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load images: $e')));
      }
    }
  }

  Future<void> _fetchSurprisingLocationImages() async {
    try {
      final result = await _graphQLService.getFavoriteLocations(
        walkId: widget.walkId,
      );
      setState(() {
        _surprisingLocationImages = List<dynamic>.from(
          result['data']['getFavoriteLocations']['favoriteLocations'],
        );
      });

      // Update map bounds to include surprising locations
      if (_mapController != null) {
        _fitBounds();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load surprising location images: $e'),
          ),
        );
      }
    }
  }

  Future<void> _fetchWalkSummary() async {
    try {
      final result = await _graphQLService.generateWalkSummary(
        walkId: widget.walkId,
      );
      setState(() {
        _walkSummary = result['data']['generateWalkSummary']['summary'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load walk summary: $e')),
        );
      }
    }
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _isLoading = true;
      _imageUrls = [];
      _surprisingLocationImages = [];
      _walkSummary = null;
      _trackingPoints = [];
    });

    try {
      await Future.wait([
        _fetchImageUrls(),
        _fetchSurprisingLocationImages(),
        _fetchWalkSummary(),
        _fetchWalkTracking(),
      ]);

      _updatePathPolylines();
      // Update map bounds after all data is loaded
      if (_mapController != null) {
        _fitBounds();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data refreshed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showImagePopup(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Stack(
            children: [
              // Full screen image
              InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
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
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _walkData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final locations = _walkData!['locations'] as List<dynamic>;
    final locationsSelected = locations.where((loc) => loc['selected'] == true);
    final locationsCollected = locations.where(
      (loc) => loc['collected'] == true,
    );
    final tasks = _walkData!['tasks'] as List<dynamic>? ?? [];
    final tasksCompleted =
        tasks.where((t) => t['status'] == 'completed').length;
    final timeSpent =
        _walkData!['timeSpent'] != null
            ? formatDuration(
              int.tryParse(_walkData!['timeSpent'].toString()) ?? 0,
            )
            : _walkData!['totalDuration'] != null
            ? formatDuration(
              int.tryParse(_walkData!['totalDuration'].toString()) ?? 0,
            )
            : '--';
    final distanceWalked =
        _walkData!['distanceTraveled']?.toStringAsFixed(1) ?? '--';
    final List<LatLng> locationPoints =
        _walkData!['locationPoints'] != null
            ? List<LatLng>.from(_walkData!['locationPoints'])
            : locations
                .where((loc) => loc['coordinates'] != null)
                .map<LatLng>(
                  (loc) => LatLng(
                    loc['coordinates']['latitude'],
                    loc['coordinates']['longitude'],
                  ),
                )
                .toList();
    final List<LatLng>? surprisingLocationPoints =
        _walkData!['surprisingLocationPoints'] != null
            ? List<LatLng>.from(_walkData!['surprisingLocationPoints'])
            : null;
    DateTime? createdAt =
        _walkData!['createdAt'] != null
            ? DateTime.tryParse(_walkData!['createdAt'])
            : null;
    final dayOfWeek = formatDayOfWeek(createdAt);
    final dateStr = formatDateStr(createdAt);
    final timeStr = formatTimeStr(createdAt);

    return Scaffold(
      body: Screenshot(
        controller: _screenshotController,
        child: SingleChildScrollView(
          child: SafeArea(
            child: Stack(
              children: [
                if (!widget.isNew)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        tooltip: 'Back',
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      if (widget.isNew) ...[
                        const Icon(
                          Icons.celebration,
                          size: 40,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Congratulations!',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ve completed your walk',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        const SizedBox(
                          height: 8,
                        ), // To make space for the arrow
                        Text(
                          'Walk Summary',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$dayOfWeek, $dateStr, $timeStr',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatUserAddress(_walkData!['userAddress']),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Save Screenshot Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : () {
                            saveSummaryScreenshot(
                              context: context,
                              trackingPoints: _trackingPoints,
                              markerPoints: locationsSelected.map((loc) => LatLng(loc['coordinates']['latitude'], loc['coordinates']['longitude'])).toList(),
                              walkSummary: _walkSummary ?? '',
                              locationsCollected: locationsCollected.length,
                              locationsSelected: locationsSelected.length,
                              tasksCompleted: tasksCompleted,
                              timeSpent: timeSpent,
                              distanceWalked: distanceWalked,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon:
                              _isSaving
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Icon(
                                    Icons.save_alt,
                                    color: Colors.white,
                                  ),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Summary',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Stats Grid
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 4,
                              bottom: 4,
                            ),
                            child: Column(
                              children: [
                                _buildStatRow(
                                  context,
                                  Icons.place,
                                  Colors.blue,
                                  'Locations',
                                  '${locationsCollected.length}/${locationsSelected.length}',
                                ),
                                const Divider(),
                                _buildStatRow(
                                  context,
                                  Icons.task_alt,
                                  Colors.green,
                                  'Tasks',
                                  '${tasksCompleted}',
                                ),
                                const Divider(),
                                _buildStatRow(
                                  context,
                                  Icons.timer,
                                  Colors.purple,
                                  'Time',
                                  timeSpent,
                                ),
                                const Divider(),
                                _buildStatRow(
                                  context,
                                  Icons.directions_walk,
                                  Colors.orange,
                                  'Distance',
                                  '${distanceWalked} km',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Map Preview
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 300,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _getMapCenter(),
                                zoom: 10,
                              ),
                              markers: {
                                ...locationsSelected
                                    .map(
                                      (location) => Marker(
                                        markerId: MarkerId(location['name']),
                                        position: LatLng(
                                          location['coordinates']['latitude'],
                                          location['coordinates']['longitude'],
                                        ),
                                        icon:
                                            locationsCollected.isNotEmpty &&
                                                    locations.indexOf(
                                                          location,
                                                        ) <
                                                        locationsCollected
                                                            .length
                                                ? BitmapDescriptor.defaultMarkerWithHue(
                                                  BitmapDescriptor.hueGreen,
                                                )
                                                : BitmapDescriptor
                                                    .defaultMarker,
                                      ),
                                    )
                                    .toSet(),
                                ..._surprisingLocationImages.asMap().entries.map(
                                  (entry) {
                                    final index = entry.key;
                                    final favorite = entry.value;
                                    return Marker(
                                      markerId: MarkerId('favorite_${index}'),
                                      infoWindow: InfoWindow(
                                        title:
                                            favorite['name'] ??
                                            'Surprising Location',
                                        snippet: favorite['description'] ?? '',
                                      ),
                                      position: LatLng(
                                        favorite['latitude'],
                                        favorite['longitude'],
                                      ),
                                      icon:
                                          _customFavoriteMarker ??
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueRed,
                                          ),
                                    );
                                  },
                                ).toSet(),
                              },
                              polylines: _pathPolylines,
                              zoomControlsEnabled: true,
                              mapToolbarEnabled: false,
                              myLocationButtonEnabled: false,
                              gestureRecognizers:
                                  <Factory<OneSequenceGestureRecognizer>>{
                                    Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer(),
                                    ),
                                  },
                              onMapCreated: (GoogleMapController controller) {
                                _mapController = controller;
                                _fitBounds();
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Walk Summary Block
                      if (_walkSummary != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Scrollbar(
                                thumbVisibility: true, // Always show scrollbar
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.format_quote,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Your Walk Story',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _walkSummary!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(height: 1.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_walkSummary == null)
                        const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 24),

                      // Surprising Location Photos
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Surprising Locations 💖',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (_surprisingLocationImages.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No photos taken during this walk',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 2,
                                      mainAxisSpacing: 2,
                                    ),
                                itemCount: _surprisingLocationImages.length,
                                itemBuilder: (context, index) {
                                  final image =
                                      _surprisingLocationImages[index];
                                  return GestureDetector(
                                    onTap:
                                        () => _showImagePopup(
                                          image['photoUrl'],
                                          'Surprising Location',
                                        ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        image['photoUrl'],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Photo Gallery
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Task Photos 📝',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (_imageUrls.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No photos taken during this walk',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 2,
                                      mainAxisSpacing: 2,
                                    ),
                                itemCount: _imageUrls.length,
                                itemBuilder: (context, index) {
                                  final image = _imageUrls[index];
                                  return GestureDetector(
                                    onTap:
                                        () => _showImagePopup(
                                          image,
                                          'Task Photo',
                                        ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        image,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (
                                          context,
                                          child,
                                          loadingProgress,
                                        ) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.error_outline,
                                              size: 48,
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
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Back to Home Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamedAndRemoveUntil('/', (route) => false);
                            },
                            child: const Text(
                              'Back to Home',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
          ),
        ),
      ),
    );
  }
}

Widget _buildStatRow(
  BuildContext context,
  IconData icon,
  Color color,
  String label,
  String value,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

String getStaticMapUrl({
  required List<LatLng> pathPoints,
  required List<LatLng> markerPoints,
  int width = 600,
  int height = 300,
  required String apiKey,
}) {
  final path = pathPoints.map((p) => '${p.latitude},${p.longitude}').join('|');
  final markerStr = markerPoints
      .map((p) => 'markers=color:red|${p.latitude},${p.longitude}')
      .join('&');
  return 'https://maps.googleapis.com/maps/api/staticmap'
      '?size=${width}x$height'
      '&$markerStr'
      '&path=color:0x0000ff|weight:4|$path'
      '&key=$apiKey';
}

class WalkSummaryContent extends StatelessWidget {
  final List<LatLng> trackingPoints;
  final List<LatLng> markerPoints;
  final String walkSummary;
  final int locationsCollected;
  final int locationsSelected;
  final int tasksCompleted;
  final String timeSpent;
  final String distanceWalked;
  final double? height;
  // Add more fields as needed

  const WalkSummaryContent({
    super.key,
    required this.trackingPoints,
    required this.markerPoints,
    required this.walkSummary,
    required this.locationsCollected,
    required this.locationsSelected,
    required this.tasksCompleted,
    required this.timeSpent,
    required this.distanceWalked,
    this.height,
    // Add more params as needed
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Walk Summary', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Image.network(
          getStaticMapUrl(
            pathPoints: trackingPoints,
            markerPoints: markerPoints,
            apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
          ),
          width: double.infinity,
          height: 300,
          fit: BoxFit.cover,
        ),
        const SizedBox(height: 16),
        Text('Locations: $locationsCollected/$locationsSelected'),
        Text('Tasks Completed: $tasksCompleted'),
        Text('Time Spent: $timeSpent'),
        Text('Distance Walked: $distanceWalked km'),
        const SizedBox(height: 16),
        Text(
          'Your Walk Story:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(walkSummary),
        // Add more summary widgets as needed
      ],
    );
  }
}

Future<void> saveSummaryScreenshot({
  required BuildContext context,
  required List<LatLng> trackingPoints,
  required List<LatLng> markerPoints,
  required String walkSummary,
  required int locationsCollected,
  required int locationsSelected,
  required int tasksCompleted,
  required String timeSpent,
  required String distanceWalked,
  // Add more params as needed
}) async {
  final controller = ScreenshotController();

  final imageBytes = await controller.captureFromLongWidget(
    InheritedTheme.captureAll(
      context,
      Material(
        child: WalkSummaryContent(
          trackingPoints: trackingPoints,
          markerPoints: markerPoints,
          walkSummary: walkSummary,
          locationsCollected: locationsCollected,
          locationsSelected: locationsSelected,
          tasksCompleted: tasksCompleted,
          timeSpent: timeSpent,
          distanceWalked: distanceWalked,
        ),
      ),
    ),
    delay: const Duration(milliseconds: 100),
    pixelRatio: 1.0,
  );

  await ImageGallerySaver.saveImage(
    imageBytes,
    quality: 100,
    name: "walk_summary_long",
  );

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Summary saved to gallery!')));
  }
}
