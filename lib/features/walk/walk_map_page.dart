import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';

class WalkMapPage extends StatefulWidget {
  final String title;
  final String walkId;
  final List<dynamic> locations;

  const WalkMapPage({
    super.key,
    required this.title,
    required this.walkId,
    required this.locations,
  });

  @override
  State<WalkMapPage> createState() => _WalkMapPageState();
}

class _WalkMapPageState extends State<WalkMapPage> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  Set<String> _collectedLocations = {};
  Map<String, dynamic>? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _timeSpent = '0:00';

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _startTimer();
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
          _checkLocationsInRange();
        });
      }
    });
  }

  void _checkLocationsInRange() {
    if (_userLocation == null) return;

    for (var location in widget.locations) {
      final markerPosition = LatLng(
        location['latitude'],
        location['longitude'],
      );
      final distance = _calculateDistance(_userLocation!, markerPosition);

      if (distance <= 100) {
        // 100 meters is our circle radius
        _collectedLocations.add(location['name']);
      }
    }
  }

  double _calculateDistance(LatLng pos1, LatLng pos2) {
    const double earthRadius = 6371000; // meters
    final double lat1 = pos1.latitude * (pi / 180);
    final double lon1 = pos1.longitude * (pi / 180);
    final double lat2 = pos2.latitude * (pi / 180);
    final double lon2 = pos2.longitude * (pi / 180);

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  String _getEstimatedTime(LatLng destination) {
    if (_userLocation == null) return 'Unknown';

    final distance = _calculateDistance(_userLocation!, destination);
    // Assuming average walking speed of 5 km/h = 1.4 m/s
    final timeInSeconds = distance / 1.4;
    final minutes = (timeInSeconds / 60).round();

    if (minutes < 1) return 'Less than a minute';
    return '$minutes minutes';
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        // Handle the photo - you can implement photo storage logic here
      }
    } catch (e) {
      // Handle camera errors
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to take photo')));
    }
  }

  void _startTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        final minutes = _stopwatch.elapsed.inMinutes;
        final seconds = _stopwatch.elapsed.inSeconds % 60;
        _timeSpent = '$minutes:${seconds.toString().padLeft(2, '0')}';
      });
    });
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
            zoomGesturesEnabled: true,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.locations[0]['latitude'],
                widget.locations[0]['longitude'],
              ),
              zoom: 12,
            ),
            markers:
                widget.locations
                    .map(
                      (location) => Marker(
                        markerId: MarkerId(location['name']),
                        infoWindow: InfoWindow(title: location['name']),
                        position: LatLng(
                          location['latitude'],
                          location['longitude'],
                        ),
                        icon:
                            _collectedLocations.contains(location['name'])
                                ? BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueGreen,
                                )
                                : BitmapDescriptor.defaultMarker,
                        onTap: () {
                          setState(() {
                            _selectedLocation = location;
                          });
                        },
                      ),
                    )
                    .toSet(),
            circles:
                _userLocation != null
                    ? {
                      Circle(
                        circleId: const CircleId('userLocationCircle'),
                        center: _userLocation!,
                        radius: 100,
                        fillColor: Colors.blue.withOpacity(0.2),
                        strokeColor: Colors.blue,
                        strokeWidth: 2,
                      ),
                    }
                    : {},
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  // Task Description Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.task_alt,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Visit all the locations marked on the map and take photos at each spot.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: List.generate(
                              5, // Total number of tasks
                              (index) => Expanded(
                                child: Container(
                                  height: 8,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index < 2 // Number of completed tasks
                                        ? Colors.green
                                        : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
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
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedLocation!['name'],
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
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
                                  'Estimated walk: ${_getEstimatedTime(LatLng(_selectedLocation!['latitude'], _selectedLocation!['longitude']))}',
                                  style: Theme.of(context).textTheme.bodyMedium,
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
                    // Time spent
                    SizedBox(
                      width: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 28,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _timeSpent,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Time',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    // Vertical divider
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    // Locations collected
                    SizedBox(
                      width: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place, size: 28, color: Colors.blue),
                          const SizedBox(height: 4),
                          Text(
                            '${_collectedLocations.length}/${widget.locations.length}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Locations',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    // Vertical divider
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    // Tasks completed
                    SizedBox(
                      width: 72,
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
                            '2/5', // Dummy data
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Tasks',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    // Vertical divider
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    // Points earned
                    SizedBox(
                      width: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 28,
                            color: Colors.amber,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '150', // Dummy data
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Points',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  children: [
                    // Back Button
                    FloatingActionButton(
                      heroTag: 'backButton',
                      backgroundColor: Theme.of(context).cardColor,
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 32),
                    // Take Photo Button
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).cardColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _takePhoto,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt, size: 24),
                            SizedBox(width: 8),
                            Text('Take Photo'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Finish Button
                    FloatingActionButton(
                      heroTag: 'finishButton',
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.check),
                      onPressed: () {
                        // Implement finish walk logic here
                        Navigator.of(
                          context,
                        ).pop(true); // Return true to indicate completion
                      },
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
    _timer?.cancel();
    _stopwatch.stop();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
