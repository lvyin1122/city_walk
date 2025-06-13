import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:mambo/features/walk/walk_map_page.dart';
import 'package:mambo/services/graphql_service.dart';

class WalkPreviewPage extends StatefulWidget {
  final String title;
  final String description;
  final String walkId;
  final List<dynamic> locations;
  final int estimatedMinutes;

  const WalkPreviewPage({
    super.key,
    required this.title,
    required this.description,
    required this.walkId,
    required this.locations,
    required this.estimatedMinutes,
  });

  @override
  State<WalkPreviewPage> createState() => _WalkPreviewPageState();
}

class _WalkPreviewPageState extends State<WalkPreviewPage> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  String? _tappedLocationId;
  Set<String> _selectedLocationIds = {};
  bool _hasInitialLocation = false;
  final GraphQLService _graphQLService = GraphQLService();

  @override
  void initState() {
    super.initState();
    print(widget.locations);
    _startLocationTracking();
  }

  void _startLocationTracking() {
    _locationSubscription = _location.onLocationChanged.listen((
      LocationData locationData,
    ) {
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _userLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
        });
        
        // Move camera to user location only on first location update
        if (_mapController != null && !_hasInitialLocation) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_userLocation!, 16),
          );
          _hasInitialLocation = true;
        }
      }
    });
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double lat1 = point1.latitude * (pi / 180);
    final double lat2 = point2.latitude * (pi / 180);
    final double dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final double dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  int _calculateEstimatedTime() {
    if (_userLocation == null || _selectedLocationIds.isEmpty) return 0;

    double totalDistance = 0;
    LatLng currentPoint = _userLocation!;
    
    // Calculate distance from user to first selected location
    final firstLocation = widget.locations[int.parse(_selectedLocationIds.first)];
    totalDistance += _calculateDistance(
      currentPoint,
      LatLng(
        firstLocation['coordinates']['latitude'],
        firstLocation['coordinates']['longitude'],
      ),
    );

    // Calculate distances between selected locations
    for (int i = 0; i < _selectedLocationIds.length - 1; i++) {
      final currentLocation = widget.locations[int.parse(_selectedLocationIds.elementAt(i))];
      final nextLocation = widget.locations[int.parse(_selectedLocationIds.elementAt(i + 1))];
      
      totalDistance += _calculateDistance(
        LatLng(
          currentLocation['coordinates']['latitude'],
          currentLocation['coordinates']['longitude'],
        ),
        LatLng(
          nextLocation['coordinates']['latitude'],
          nextLocation['coordinates']['longitude'],
        ),
      );
    }

    // Assuming average walking speed of 5 km/h
    // Assuming average stationary time of 10 minutes per location
    // Convert distance to minutes (distance in km * 60 minutes / 5 km/h)
    return ((totalDistance * 12) + (_selectedLocationIds.length * 10)).round();
  }

  String _formatEstimatedTime(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return '$hours ${hours == 1 ? 'hour' : 'hours'} $remainingMinutes minutes';
  }

  Map<String, dynamic>? _getLocationById(String id) {
    final index = int.tryParse(id);
    if (index == null || index >= widget.locations.length) return {};
    return widget.locations[index];
  }

  Widget _buildLocationInfoCard() {
    print(_tappedLocationId);
    if (_tappedLocationId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap on any location marker to see more information and select locations to visit',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tappedLocation = _getLocationById(_tappedLocationId!);
    if (tappedLocation!.isEmpty) return const SizedBox.shrink();

    final bool isSelected = _selectedLocationIds.contains(_tappedLocationId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tappedLocation['name'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedLocationIds.add(_tappedLocationId!);
                      } else {
                        _selectedLocationIds.remove(_tappedLocationId);
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _tappedLocationId = null;
                    });
                  },
                ),
              ],
            ),
            Text(
              tappedLocation['description'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onStartWalk() async {
    if (_selectedLocationIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one location to visit'),
        ),
      );
      return;
    }

    final estimatedTime = _calculateEstimatedTime();
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Start Walk?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you ready to begin this walk? Make sure you have comfortable shoes and water!',
              ),
              const SizedBox(height: 16),
              Text(
                'Selected locations: ${_selectedLocationIds.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated time: ${_formatEstimatedTime(estimatedTime)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Yet'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Let's Go!"),
            ),
          ],
        );
      },
    );

    if (shouldStart == true && mounted) {
      try {
        // Update walk status to in_progress
        await _graphQLService.updateWalkStatus(
          walkId: widget.walkId,
          status: 'in_progress',
        );

        final selectedLocations = _selectedLocationIds
            .map((id) => widget.locations[int.parse(id)])
            .toList();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WalkMapPage(
              title: widget.title,
              walkId: widget.walkId,
              locations: selectedLocations,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start walk: $e')),
          );
        }
      }
    }
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
            mapToolbarEnabled: true,
            zoomControlsEnabled: false,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.locations[0]['coordinates']['latitude'],
                widget.locations[0]['coordinates']['longitude'],
              ),
              zoom: 12,
            ),
            markers: widget.locations.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final location = entry.value;
                return Marker(
                  markerId: MarkerId(location['name']),
                  infoWindow: InfoWindow(title: location['name']),
                  position: LatLng(
                    location['coordinates']['latitude'],
                    location['coordinates']['longitude'],
                  ),
                  icon: _selectedLocationIds.contains(index.toString())
                      ? BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        )
                      : BitmapDescriptor.defaultMarker,
                  onTap: () {
                    print(index);
                    setState(() {
                      _tappedLocationId = index.toString();
                    });
                  },
                );
              },
            ).toSet(),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            top: 4,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  // Walk Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Estimated time: ${_formatEstimatedTime(widget.estimatedMinutes)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Locations: ${widget.locations.length}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Location Info Card (when selected)
                ],
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
                    _buildLocationInfoCard(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FloatingActionButton(
                          heroTag: 'backButton',
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
                            onPressed: _onStartWalk,
                            child: const Text(
                              'Start Walk',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
