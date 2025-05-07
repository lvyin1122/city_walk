import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapTest extends StatefulWidget {
  // final List<dynamic> locations;

  const MapTest({super.key});

  @override
  State<MapTest> createState() => _MapTestState();
}

class _MapTestState extends State<MapTest> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(37.7749, -122.4194),
          zoom: 12,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        // markers: widget.locations.map((location) => Marker(
        //   markerId: MarkerId(location['id'].toString()),
        //       position: LatLng(location['latitude'], location['longitude']),
        //     ),
        //   )
        //   .toSet(),
      ),
    );
  }
}