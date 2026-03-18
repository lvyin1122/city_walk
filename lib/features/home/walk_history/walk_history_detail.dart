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
        title: Text('步行历史', style: AppTextStyles.headline2),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
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
                '日期：${walkDetails['date']}',
                style: AppTextStyles.bodyText1,
              ),
              Text(
                '时长：${walkDetails['duration']}',
                style: AppTextStyles.bodyText1,
              ),
              Text(
                '距离：${walkDetails['distance']}',
                style: AppTextStyles.bodyText1,
              ),
              SizedBox(height: 20),
              Text('完成任务', style: AppTextStyles.headline2),
              Text('10/10', style: AppTextStyles.bodyText1),
              SizedBox(height: 20),
              Text('路线地图', style: AppTextStyles.headline2),
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
                      infoWindow: InfoWindow(title: '起点'),
                    ),
                    Marker(
                      markerId: MarkerId('end'),
                      position: LatLng(37.7849, -122.4094),
                      infoWindow: InfoWindow(title: '终点'),
                    ),
                  ]),
                ),
              ),
              SizedBox(height: 20),
              Text('照片画廊', style: AppTextStyles.headline2),
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
