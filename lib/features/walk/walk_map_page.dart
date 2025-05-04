import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';
import 'dart:collection';

class WalkMapPage extends StatefulWidget {
  final String walkId;
  final List<dynamic> selectedLocations;
  final String title;

  const WalkMapPage({
    Key? key,
    required this.walkId,
    required this.selectedLocations,
    required this.title,
  }) : super(key: key);

  @override
  _WalkMapPageState createState() => _WalkMapPageState();
}

class _WalkMapPageState extends State<WalkMapPage> {
  late GoogleMapController _mapController;
  Location location = Location();
  LocationData? _currentLocation;
  Timer? _locationTimer;
  Database? _database;
  Set<String> _collectedLocations = {};
  final double _collectionRadius = 50; // meters
  final List<LatLng> _routePoints = [];
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initDatabase().then((_) {
      _loadSavedRoute();
      _startLocationTracking();
    });
  }

  Future<void> _initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'walk_locations.db'),
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE walk_locations(id INTEGER PRIMARY KEY AUTOINCREMENT, walkId TEXT, latitude REAL, longitude REAL, timestamp INTEGER)',
        );
        await db.execute(
          'CREATE TABLE route_points(id INTEGER PRIMARY KEY AUTOINCREMENT, walkId TEXT, latitude REAL, longitude REAL, timestamp INTEGER)',
        );
      },
      version: 1,
    );
  }

  void _startLocationTracking() {
    location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentLocation = currentLocation;
        _routePoints.add(
          LatLng(currentLocation.latitude!, currentLocation.longitude!),
        );
        _updateRoutePolyline();
      });
      _checkProximityToLocations();
    });

    _locationTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _saveCurrentLocation();
    });
  }

  void _updateRoutePolyline() {
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: PolylineId('user_route'),
          points: _routePoints,
          color: AppColors.primaryColor,
          width: 5,
        ),
      );
    });
  }

  Future<void> _saveCurrentLocation() async {
    if (_currentLocation == null || _database == null) return;

    await _database!.insert('walk_locations', {
      'walkId': widget.walkId,
      'latitude': _currentLocation!.latitude,
      'longitude': _currentLocation!.longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _database!.insert('route_points', {
      'walkId': widget.walkId,
      'latitude': _currentLocation!.latitude,
      'longitude': _currentLocation!.longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _checkProximityToLocations() {
    if (_currentLocation == null) return;

    for (var location in widget.selectedLocations) {
      final coordinates =
          location['coordinates'] is String
              ? jsonDecode(location['coordinates'])
              : location['coordinates'];

      final latitude =
          coordinates['latitude'] is String
              ? double.parse(coordinates['latitude'])
              : coordinates['latitude'].toDouble();

      final longitude =
          coordinates['longitude'] is String
              ? double.parse(coordinates['longitude'])
              : coordinates['longitude'].toDouble();

      print(latitude);
      print(longitude);

      final locationLatLng = LatLng(latitude, longitude);

      final userLatLng = LatLng(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );

      final distance = _calculateDistance(locationLatLng, userLatLng);

      if (distance <= _collectionRadius) {
        setState(() {
          _collectedLocations.add(location['id'].toString());
        });
      }
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Implement Haversine formula here
    // For now, returning a simple euclidean distance as placeholder
    return ((point1.latitude - point2.latitude).abs() +
            (point1.longitude - point2.longitude).abs()) *
        111000; // Rough conversion to meters
  }

  Set<Marker> _createMarkers() {
    Set<Marker> markers = {};

    // Add selected location markers
    for (var location in widget.selectedLocations) {
      final isCollected = _collectedLocations.contains(
        location['id'].toString(),
      );

      final coordinates =
          location['coordinates'] is String
              ? jsonDecode(location['coordinates'])
              : location['coordinates'];

      final latitude =
          coordinates['latitude'] is String
              ? double.parse(coordinates['latitude'])
              : coordinates['latitude'].toDouble();

      final longitude =
          coordinates['longitude'] is String
              ? double.parse(coordinates['longitude'])
              : coordinates['longitude'].toDouble();

      markers.add(
        Marker(
          markerId: MarkerId(location['id'].toString()),
          position: LatLng(latitude, longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isCollected ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: location['name'],
            snippet: isCollected ? 'Collected!' : 'Not collected yet',
          ),
        ),
      );
    }

    // Add current user location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('currentLocation'),
          position: LatLng(
            _currentLocation!.latitude!,
            _currentLocation!.longitude!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: 'You are here'),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.selectedLocations.first['coordinates']['latitude']
                    .toDouble(),
                widget.selectedLocations.first['coordinates']['longitude']
                    .toDouble(),
              ),
              zoom: 15,
            ),
            markers: _createMarkers(),
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(widget.title, style: AppTextStyles.headline2),
                    SizedBox(height: 8),
                    Text(
                      'Locations collected: ${_collectedLocations.length}/${widget.selectedLocations.length}',
                      style: AppTextStyles.bodyText1,
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
    _locationTimer?.cancel();
    _database?.close();
    super.dispose();
  }

  Future<void> _loadSavedRoute() async {
    if (_database == null) return;

    final List<Map<String, dynamic>> routePoints = await _database!.query(
      'route_points',
      where: 'walkId = ?',
      whereArgs: [widget.walkId],
      orderBy: 'timestamp ASC',
    );

    setState(() {
      _routePoints.addAll(
        routePoints.map(
          (point) =>
              LatLng(point['latitude'] as double, point['longitude'] as double),
        ),
      );
      _updateRoutePolyline();
    });
  }
}
