import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';

class WalkHistoryDetailPage extends StatelessWidget {
  final Map<String, dynamic> walkDetails;

  WalkHistoryDetailPage({required this.walkDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Walk History', style: AppTextStyles.headline2),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${walkDetails['title']}',
                style: AppTextStyles.headline2,
              ),
              Image.network('https://placehold.co/600x400/png'),
              Text(
                'Date: ${walkDetails['date']}',
                style: AppTextStyles.bodyText1,
              ),
              Text(
                'Duration: ${walkDetails['duration']}',
                style: AppTextStyles.bodyText1,
              ),
              Text(
                'Distance: ${walkDetails['distance']}',
                style: AppTextStyles.bodyText1,
              ),
              SizedBox(height: 20),
              Text('Tasks Completed', style: AppTextStyles.headline2),
              Text('10/10', style: AppTextStyles.bodyText1),
              SizedBox(height: 20),
              Text('Route Map', style: AppTextStyles.headline2),
              Container(
                height: 200,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(37.7749, -122.4194), // Example coordinates
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
              SizedBox(height: 20),
              Text('Photo Gallery', style: AppTextStyles.headline2),
              Container(
                child: StaggeredGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  children: <Widget>[
                    Image.network('https://placehold.co/600x400/png'),
                    Image.network('https://placehold.co/400x400/png'),
                    Image.network('https://placehold.co/400x600/png'),
                    Image.network('https://placehold.co/600x600/png'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
