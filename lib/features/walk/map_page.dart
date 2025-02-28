import 'dart:math';

import 'package:city_walk/features/walk/walk_summary.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';
import 'package:location/location.dart';

class MapPage extends StatefulWidget {
  final String title;
  final String description;
  final int difficulty;
  final List<String> keywords;
  final String taskTitle;
  final String taskDescription;
  final int totalTasks;

  MapPage({
    required this.title,
    required this.description,
    required this.difficulty,
    required this.keywords,
    required this.taskTitle,
    required this.taskDescription,
    required this.totalTasks,
  });

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController _mapController;
  bool _isWalking = false;
  int _currentTaskProgress = 2;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocationData>(
      future: _getUserLocation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return Center(child: Text('Unable to get location'));
        }

        final userLocation = snapshot.data!;
        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  _fitMarkers(controller, userLocation);
                },
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    userLocation.latitude!,
                    userLocation.longitude!,
                  ),
                  zoom: 12,
                ),
                markers: _createMarkers(userLocation),
                myLocationEnabled: true,
              ),
              if (!_isWalking)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Card(
                    margin: EdgeInsets.all(16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: AppTextStyles.headline2),
                          SizedBox(height: 8.0),
                          Text(
                            widget.description,
                            style: AppTextStyles.bodyText1,
                          ),
                          SizedBox(height: 8.0),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < widget.difficulty
                                    ? Icons.star
                                    : Icons.star_border,
                                color: AppColors.primaryColor,
                              );
                            }),
                          ),
                          SizedBox(height: 8.0),
                          Wrap(
                            spacing: 8.0,
                            children:
                                widget.keywords
                                    .map(
                                      (keyword) => Chip(label: Text(keyword)),
                                    )
                                    .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isWalking)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Card(
                    margin: EdgeInsets.all(16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(widget.taskTitle),
                          SizedBox(height: 8.0),
                          Text(widget.taskDescription),
                          SizedBox(height: 16.0),
                          Row(
                            children: List.generate(widget.totalTasks, (index) {
                              return Expanded(
                                child: Container(
                                  height: 8.0,
                                  margin: EdgeInsets.symmetric(horizontal: 2.0),
                                  decoration: BoxDecoration(
                                    color:
                                        index < _currentTaskProgress
                                            ? AppColors.primaryColor
                                            : AppColors.secondaryColor
                                                .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                ),
                              );
                            }),
                          ),
                          SizedBox(height: 8.0),
                          Text(
                            '60% Complete', // Make this dynamic to match progress
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyText1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                bottom: 32.0,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isWalking)
                      FloatingActionButton.extended(
                        onPressed: () {
                          setState(() {
                            _isWalking = true;
                          });
                          _mapController.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(
                                userLocation.latitude!,
                                userLocation.longitude!,
                              ),
                              16.0, // Zoom level for user location
                            ),
                          );
                        },
                        icon: Icon(Icons.directions_walk),
                        label: Text('Let\'s go!', style: AppTextStyles.buttonTextWhite),
                        backgroundColor: AppColors.primaryColor,
                      ),
                    if (_isWalking) ...[
                      FloatingActionButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.exit_to_app,
                          color: AppColors.buttonTextColor,
                        ),
                        backgroundColor: AppColors.alertColor,
                      ),
                      SizedBox(width: 16.0),
                      FloatingActionButton.extended(
                        onPressed: () {
                          // Logic to finish the walk
                          print('Finish Walk');
                        },
                        icon: Icon(Icons.camera,
                            color: AppColors.textColor),
                        label: Text(
                          'Take a photo',
                          style: AppTextStyles.buttonTextBlack,
                        ),
                        backgroundColor: Colors.white,
                      ),
                      SizedBox(width: 16.0),
                      FloatingActionButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => WalkSummaryPage(
                              walkDetails: {
                                'title': widget.title,
                                'date': DateTime.now().toString(),
                                'duration': '1 hour',
                                'distance': '5 km',
                              },
                            )),
                          );  
                        },
                        child: Icon(Icons.check,
                            color: AppColors.buttonTextColor),
                        backgroundColor: AppColors.primaryColor,
                      ),
                    ],
                  ],
                ),
              ),
              // Back button
              if (!_isWalking)
                Positioned(
                  left: 16.0,
                  bottom: 32.0,
                  child: FloatingActionButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Icon(Icons.arrow_back),
                    backgroundColor: AppColors.primaryColor,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<LocationData> _getUserLocation() async {
    Location location = Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        throw Exception('Location services are disabled.');
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        throw Exception('Location permissions are denied');
      }
    }

    return await location.getLocation();
  }

  Set<Marker> _createMarkers(LocationData userLocation) {
    final BitmapDescriptor starIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueYellow,
    );

    return {
      Marker(
        markerId: MarkerId('location1'),
        position: LatLng(22.3193, 114.1694), // Central Hong Kong
        icon: starIcon,
        infoWindow: InfoWindow(
          title: 'Location 1',
          snippet: 'Central Hong Kong',
        ),
      ),
      Marker(
        markerId: MarkerId('location2'),
        position: LatLng(22.3027, 114.1772), // Tsim Sha Tsui
        icon: starIcon,
        infoWindow: InfoWindow(title: 'Location 2', snippet: 'Tsim Sha Tsui'),
      ),
      Marker(
        markerId: MarkerId('location3'),
        position: LatLng(22.3364, 114.1628), // Kowloon Tong
        icon: starIcon,
        infoWindow: InfoWindow(title: 'Location 3', snippet: 'Kowloon Tong'),
      ),
      Marker(
        markerId: MarkerId('location4'),
        position: LatLng(22.2849, 114.1588), // Victoria Peak
        icon: starIcon,
        infoWindow: InfoWindow(title: 'Location 4', snippet: 'Victoria Peak'),
      ),
      Marker(
        markerId: MarkerId('location5'),
        position: LatLng(22.3964, 114.1095), // New Territories
        icon: starIcon,
        infoWindow: InfoWindow(title: 'Location 5', snippet: 'New Territories'),
      ),
      Marker(
        markerId: MarkerId('userLocation'),
        position: LatLng(userLocation.latitude!, userLocation.longitude!),
      ),
    };
  }

  void _fitMarkers(GoogleMapController controller, LocationData userLocation) {
    final markers = _createMarkers(userLocation);
    if (markers.isEmpty) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: markers.first.position,
      northeast: markers.first.position,
    );
    for (var marker in markers) {
      bounds = LatLngBounds(
        southwest: LatLng(
          min(bounds.southwest.latitude, marker.position.latitude),
          min(bounds.southwest.longitude, marker.position.longitude),
        ),
        northeast: LatLng(
          max(bounds.northeast.latitude, marker.position.latitude),
          max(bounds.northeast.longitude, marker.position.longitude),
        ),
      );
    }

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
  }
}
