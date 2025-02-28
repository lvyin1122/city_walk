import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class WalkSummaryPage extends StatelessWidget {
  final Map<String, dynamic> walkDetails;

  WalkSummaryPage({required this.walkDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Walk Summary', style: AppTextStyles.headline2),
        backgroundColor: AppColors.primaryColor,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Date: ${walkDetails['date']}',
                    style: AppTextStyles.bodyText1,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Duration: ${walkDetails['duration']}',
                    style: AppTextStyles.bodyText1,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Distance: ${walkDetails['distance']}',
                    style: AppTextStyles.bodyText1,
                  ),
                  SizedBox(height: 30),
                  Text('Tasks Completed', style: AppTextStyles.headline2),
                  Text('10/10', style: AppTextStyles.bodyText1),
                  SizedBox(height: 30),
                  Text('Route Map', style: AppTextStyles.headline2),
                  Container(
                    height: 200,
                    margin: EdgeInsets.symmetric(vertical: 20.0),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          37.7749,
                          -122.4194,
                        ), // Example coordinates
                        zoom: 14.0,
                      ),
                      markers: Set<Marker>.of(<Marker>[
                        Marker(
                          markerId: MarkerId('start'),
                          position: LatLng(37.7749, -122.4194),
                          infoWindow: InfoWindow(title: 'Start'),
                        ),
                        Marker(
                          markerId: MarkerId('end'),
                          position: LatLng(37.7849, -122.4094),
                          infoWindow: InfoWindow(title: 'End'),
                        ),
                      ]),
                    ),
                  ),
                  SizedBox(height: 30),
                  Text('Photo Gallery', style: AppTextStyles.headline2),
                  Container(
                    height: 200,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        Image.network('https://via.placeholder.com/150'),
                        SizedBox(width: 10),
                        Image.network('https://via.placeholder.com/150'),
                        SizedBox(width: 10),
                        Image.network('https://via.placeholder.com/150'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingActionButton(
              onPressed: () {
                print('Generate AI Map');
              },
              child: Text('Generate AI Map', style: AppTextStyles.buttonTextWhite),
              backgroundColor: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
