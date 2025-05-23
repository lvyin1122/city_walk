import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mambo/features/walk/walk_summary.dart';
import 'package:mambo/services/graphql_service.dart';

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

  @override
  void initState() {
    super.initState();
    _configureLocationSettings();
    _startLocationTracking();
    _startTimer();
    _fetchTask();
    _startLocationHistoryTracking();
  }

  Future<void> _configureLocationSettings() async {
    // Enable background mode
    await _location.enableBackgroundMode(enable: true);
    
    // Configure location settings
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000, // 10 seconds
      distanceFilter: 10, // 10 meters
    );
  }

  void _startLocationTracking() {
    _locationSubscription = _location.onLocationChanged.listen(
      (LocationData locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {
          setState(() {
            _userLocation = LatLng(
              locationData.latitude!,
              locationData.longitude!,
            );
            _checkLocationsInRange();
          });
        }
      },
      onError: (error) {
        print('Location error: $error');
      },
    );
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

  Future<void> _fetchTask() async {
    try {
      final result = await _graphQLService.generateTask(walkId: widget.walkId);
      setState(() {
        _currentTask = result['data']['generateTaskWithGpt']['task'];
        _isLoadingTask = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTask = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load task')));
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _showPhotoSourceBottomSheet();
      if (photo != null) {
        setState(() {
          _photosFulfilled++;
        });
        // Check if task is completed
        if (_currentTask?['photosRequired'] != null &&
            _photosFulfilled >= _currentTask?['photosRequired']!) {
          if (mounted) {
            await _showCongratulationsModal();
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to take photo')));
    }
  }

  Future<XFile?> _showPhotoSourceBottomSheet() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) return null;

    return await _picker.pickImage(source: source);
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
                  'Congratulations!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You\'ve completed the task!',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Get ready for your next challenge...',
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
        final hours = _stopwatch.elapsed.inHours;
        final minutes = _stopwatch.elapsed.inMinutes % 60;
        final seconds = _stopwatch.elapsed.inSeconds % 60;

        if (hours > 0) {
          _timeSpent =
              '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else {
          _timeSpent = '$minutes:${seconds.toString().padLeft(2, '0')}';
        }
      });
    });
  }

  int _calculatePoints() {
    final locationPoints =
        (_collectedLocations.length / widget.locations.length * 100).round();
    final taskPoints = _tasksCompleted * 50;
    return locationPoints + taskPoints;
  }

  void _startLocationHistoryTracking() {
    _locationHistoryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_userLocation != null) {
        setState(() {
          if (_lastRecordedLocation != null) {
            _distanceWalked += _calculateDistance(
              _lastRecordedLocation!,
              _userLocation!,
            ) / 1000;
          }
          
          _lastRecordedLocation = _userLocation;
          
          _userLocationHistory.add(_userLocation!);
          _updatePathPolylines();
        });
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
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
                target: LatLng(
                  widget.locations[0]['coordinates']['latitude'],
                  widget.locations[0]['coordinates']['longitude'],
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
                            location['coordinates']['latitude'],
                            location['coordinates']['longitude'],
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
              polylines: _pathPolylines,
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
                              color: Colors.grey.withOpacity(0.3),
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
                                      '${_distanceWalked.toStringAsFixed(1)} km',
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
                        padding: const EdgeInsets.all(16.0),
                        child:
                            _isLoadingTask
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                            _currentTask?['description'] ?? '-',
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
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
                                                        ? Colors.green
                                                        : Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(4),
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
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
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
                                    'Estimated walk: ${_getEstimatedTime(LatLng(_selectedLocation!['coordinates']['latitude'], _selectedLocation!['coordinates']['longitude']))}',
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
                        width: 60,
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
                              '${_collectedLocations.length}/${widget.locations.length}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Locations',
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
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      // Tasks completed
                      SizedBox(
                        width: 60,
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
                              'Tasks',
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
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      // Points earned
                      SizedBox(
                        width: 60,
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
                              '${_calculatePoints()}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Points',
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
                    children: [
                      // Back Button
                      FloatingActionButton(
                        heroTag: 'backButton',
                        backgroundColor: Theme.of(context).cardColor,
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.black87,
                        ),
                        onPressed: () async {
                          final shouldPop = await _onWillPop();
                          if (shouldPop && mounted) {
                            Navigator.of(context).pop();
                          }
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
                              Icon(Icons.add_a_photo, size: 24),
                              SizedBox(width: 8),
                              Text('Add Photo'),
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
                        onPressed: () async {
                          final shouldFinish = await _onFinishWalk();
                          if (shouldFinish && mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (context) => WalkSummary(
                                      walkId: widget.walkId,
                                      locations: widget.locations,
                                      locationsCollected:
                                          _collectedLocations.length,
                                      tasksCompleted: _tasksCompleted,
                                      distanceWalked: _distanceWalked,
                                      pointsEarned: _calculatePoints(),
                                      timeSpent: _timeSpent,
                                    ),
                              ),
                            );
                          }
                        },
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
    _locationHistoryTimer?.cancel();
    _timer?.cancel();
    _stopwatch.stop();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    // Disable background mode when disposing
    _location.enableBackgroundMode(enable: false);
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Cancel Walk?'),
          content: const Text(
            'Are you sure you want to cancel the current walk? All progress will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, Continue'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
    return shouldPop ?? false;
  }

  Future<bool> _onFinishWalk() async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Finish Walk?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to finish this walk?'),
              const SizedBox(height: 16),
              Text('Summary:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '• ${_collectedLocations.length}/${widget.locations.length} locations visited',
              ),
              Text('• $_tasksCompleted tasks completed'),
              Text('• ${_distanceWalked.toStringAsFixed(1)} km walked'),
              Text('• ${_calculatePoints()} points earned'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, Continue'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Finish'),
            ),
          ],
        );
      },
    );
    return shouldFinish ?? false;
  }
}
