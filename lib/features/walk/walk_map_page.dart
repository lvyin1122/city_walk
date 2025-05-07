import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class WalkMapPage extends StatefulWidget {
  final String title;
  final String walkId;
  final List<dynamic> locations;

  const WalkMapPage({super.key, required this.title, required this.walkId, required this.locations});

  @override
  State<WalkMapPage> createState() => _WalkMapPageState();
}

class _WalkMapPageState extends State<WalkMapPage> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  Set<String> _collectedLocations = {};

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  void _startLocationTracking() {
    _locationSubscription = _location.onLocationChanged.listen((LocationData locationData) {
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
      final markerPosition = LatLng(location['latitude'], location['longitude']);
      final distance = _calculateDistance(_userLocation!, markerPosition);
      
      if (distance <= 100) { // 100 meters is our circle radius
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

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.locations[0]['latitude'], widget.locations[0]['longitude']),
          zoom: 12,
        ),
        markers: widget.locations.map((location) => Marker(
          markerId: MarkerId(location['name']),
          infoWindow: InfoWindow(
            title: location['name'],
            snippet: location['description'],
          ),
          position: LatLng(location['latitude'], location['longitude']),
          icon: _collectedLocations.contains(location['name'])
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarker,
        )).toSet(),
        circles: _userLocation != null ? {
          Circle(
            circleId: const CircleId('userLocationCircle'),
            center: _userLocation!,
            radius: 100,
            fillColor: Colors.blue.withOpacity(0.2),
            strokeColor: Colors.blue,
            strokeWidth: 2,
          ),
        } : {},
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
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