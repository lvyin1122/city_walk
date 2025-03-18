import 'walk_history_detail.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';

class WalkHistoryPage extends StatelessWidget {
  final List<Map<String, dynamic>> walkHistory = [
    {
      'title': 'Downtown Exploration',
      'date': '2023-10-01',
      'duration': '45 mins',
      'distance': '3.5 km',
    },
    {
      'title': 'City Park Walk',
      'date': '2023-09-28',
      'duration': '30 mins',
      'distance': '2.0 km',
    },
    {
      'title': 'Historic District Tour',
      'date': '2023-09-25',
      'duration': '60 mins',
      'distance': '5.0 km',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Walk History', style: AppTextStyles.headline2),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        itemCount: walkHistory.length,
        itemBuilder: (context, index) {
          final walk = walkHistory[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: ListTile(
              title: Text(walk['title'], style: AppTextStyles.headline2),
              subtitle: Text(
                'Date: ${walk['date']}\nDuration: ${walk['duration']}\nDistance: ${walk['distance']}',
                style: AppTextStyles.bodyText1,
              ),
              leading: Icon(Icons.directions_walk, color: AppColors.primaryColor),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WalkHistoryDetailPage(walkDetails: walk),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
