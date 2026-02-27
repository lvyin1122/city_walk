import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class QuickStartMapPage extends StatefulWidget {
  const QuickStartMapPage({super.key});

  @override
  State<QuickStartMapPage> createState() => _QuickStartMapPageState();
}

class _QuickStartMapPageState extends State<QuickStartMapPage> {
  static const LatLng _defaultPosition = LatLng(37.7749, -122.4194);
  GoogleMapController? _mapController;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _setLocationReady(null);
          return;
        }
      }

      final permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted &&
          permissionGranted != PermissionStatus.grantedLimited) {
        _setLocationReady(null);
        return;
      }

      final locationData = await location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Location request timed out'),
      );
      if (locationData.latitude != null && locationData.longitude != null) {
        _setLocationReady(
          LatLng(locationData.latitude!, locationData.longitude!),
        );
      } else {
        _setLocationReady(null);
      }
    } catch (_) {
      _setLocationReady(null);
    }
  }

  void _setLocationReady(LatLng? position) {
    if (mounted) {
      setState(() => _userLocation = position);
      if (position != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(position, 15),
        );
      }
    }
  }

  LatLng get _initialPosition => _userLocation ?? _defaultPosition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Start'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GoogleMap(
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        compassEnabled: true,
        zoomControlsEnabled: false,
        zoomGesturesEnabled: true,
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 15,
        ),
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          if (_userLocation != null) {
            controller.animateCamera(
              CameraUpdate.newLatLngZoom(_userLocation!, 15),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
