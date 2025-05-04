import 'dart:convert';
import 'dart:math';
import 'package:mambo/features/walk/walk_summary.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';
import 'package:location/location.dart';
import 'package:mambo/features/walk/walk_map_page.dart';

class MapPage extends StatefulWidget {
  final String title;
  final String description;
  final int difficulty;
  final String walkId;
  final List<dynamic> locations;

  MapPage({
    required this.title,
    required this.description,
    required this.difficulty,
    required this.walkId,
    required this.locations,
  });

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController _mapController;
  bool _isWalking = false;
  final ValueNotifier<List<dynamic>> _selectedLocationsNotifier = ValueNotifier(
    [],
  );
  final int _currentTaskProgress = 2;
  LocationData? _currentUserLocation;

  List<dynamic> get _selectedLocations => _selectedLocationsNotifier.value;

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
              ValueListenableBuilder<List<dynamic>>(
                valueListenable: _selectedLocationsNotifier,
                builder: (context, selectedLocations, child) {
                  return MapWidget(
                    onMapCreated: (controller) {
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
                    markers: _createMarkers(
                      _currentUserLocation ?? userLocation,
                    ),
                  );
                },
              ),

              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Card(
                        margin: EdgeInsets.all(16.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ValueListenableBuilder<List<dynamic>>(
                            valueListenable: _selectedLocationsNotifier,
                            builder: (context, selectedLocations, child) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: AppTextStyles.headline2,
                                  ),
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
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 100,
                      left: 0,
                      right: 50,
                      child: Card(
                        margin: EdgeInsets.all(16.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ValueListenableBuilder<List<dynamic>>(
                            valueListenable: _selectedLocationsNotifier,
                            builder: (context, selectedLocations, child) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Locations',
                                    style: AppTextStyles.bodyText1,
                                  ),
                                  Text(
                                    '${selectedLocations.length} / ${widget.locations.length}',
                                    style: AppTextStyles.bodyText1,
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children:
                                          selectedLocations
                                              .map(
                                                (location) => ChoiceChip(
                                                  label: Text(
                                                    location['name'] ??
                                                        'Location',
                                                  ),
                                                  selected: true,
                                                  onSelected: (bool selected) {
                                                    _selectedLocationsNotifier
                                                        .value = selected
                                                            ? [
                                                              ..._selectedLocations,
                                                              location,
                                                            ]
                                                            : _selectedLocations
                                                                .where(
                                                                  (element) =>
                                                                      element !=
                                                                      location,
                                                                )
                                                                .toList();
                                                  },
                                                  selectedColor:
                                                      AppColors.primaryColor,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ),
                                ],
                              );
                            },
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => WalkMapPage(
                                          walkId: widget.walkId,
                                          selectedLocations: _selectedLocations,
                                          title: widget.title,
                                        ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.directions_walk),
                              label: Text(
                                'Let\'s go!',
                                style: AppTextStyles.buttonTextWhite,
                              ),
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
                              icon: Icon(
                                Icons.camera,
                                color: AppColors.textColor,
                              ),
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
                                  MaterialPageRoute(
                                    builder:
                                        (context) => WalkSummaryPage(
                                          walkDetails: {
                                            'title': widget.title,
                                            'date': DateTime.now().toString(),
                                            'duration': '1 hour',
                                            'distance': '5 km',
                                          },
                                        ),
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.check,
                                color: AppColors.buttonTextColor,
                              ),
                              backgroundColor: AppColors.primaryColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Back button
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
    _currentUserLocation = userLocation;
    final BitmapDescriptor defaultIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueBlue,
    );
    final BitmapDescriptor selectedIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRed,
    );

    Set<Marker> markers = {};

    // Add markers for each location from the API
    for (var i = 0; i < widget.locations.length; i++) {
      final location = widget.locations[i];
      final markerId = 'location$i';

      try {
        // Get coordinates and convert to double if needed
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
            markerId: MarkerId(markerId),
            position: LatLng(latitude, longitude),
            icon:
                _selectedLocations.contains(location)
                    ? selectedIcon
                    : defaultIcon,
            infoWindow: InfoWindow(
              title: location['name'] ?? 'Location',
              snippet: location['description'] ?? 'No description available',
            ),
            onTap:
                () => {
                  if (!_selectedLocations.contains(location))
                    {
                      _selectedLocationsNotifier.value = [
                        ..._selectedLocations,
                        location,
                      ],
                    }
                  else
                    {
                      _selectedLocationsNotifier.value =
                          _selectedLocations
                              .where((element) => element != location)
                              .toList(),
                    },
                },
          ),
        );
      } catch (e) {
        print('Error parsing coordinates: $e');
        print('Location data: $location');
        // You might want to skip this location or handle the error in some other way
      }
    }

    // Add user location marker
    markers.add(
      Marker(
        markerId: MarkerId('userLocation'),
        position: LatLng(userLocation.latitude!, userLocation.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    return markers;
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

  @override
  void dispose() {
    _selectedLocationsNotifier.dispose();
    super.dispose();
  }
}

class MapWidget extends StatelessWidget {
  final Function(GoogleMapController) onMapCreated;
  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;

  const MapWidget({
    Key? key,
    required this.onMapCreated,
    required this.initialCameraPosition,
    required this.markers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: initialCameraPosition,
      markers: markers,
      myLocationEnabled: false,
      zoomControlsEnabled: true,
      compassEnabled: true,
    );
  }
}
