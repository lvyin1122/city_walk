import 'package:mambo/features/walk/map_page.dart';
import 'package:flutter/material.dart';
import 'package:mambo/features/walk/map_test.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class RecommendedWalksPage extends StatelessWidget {
  final List<dynamic> walks;

  const RecommendedWalksPage({
    Key? key,
    required this.walks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: walks.length,
              itemBuilder: (context, index) {
                final walk = walks[index];

                // convert locations to a list of maps
                final locations = walk['locations'].map((location) => {
                  'name': location['name'],
                  'latitude': location['coordinates']['latitude'],
                  'longitude': location['coordinates']['longitude'],
                  'description': location['description'],
                  'estimatedTime': location['estimatedTime'],
                }).toList();

                return WalkCard(
                  title: walk['title'] ?? 'Unnamed Walk',
                  description: walk['description'] ?? 'No description',
                  difficulty: walk['difficulty'] ?? 3,
                  locations: locations,
                  walkId: walk['Id'] ?? '',
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton(
                onPressed: () {
                  // Logic to regenerate recommended plans
                  print('Regenerate recommended plans');
                },
                child: Icon(Icons.refresh),
                backgroundColor: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WalkCard extends StatefulWidget {
  final String title;
  final String walkId;
  final String description;
  final int difficulty;
  final List<dynamic> locations;

  WalkCard({
    required this.title,
    required this.walkId,
    required this.description,
    required this.difficulty,
    required this.locations,
  });

  @override
  _WalkCardState createState() => _WalkCardState();
}

class _WalkCardState extends State<WalkCard> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapPage(
              title: widget.title,
              walkId: widget.walkId,
              description: widget.description,
              difficulty: widget.difficulty,
              locations: widget.locations,
            ),
            // builder: (context) => MapTest(locations: widget.locations),
          ),
        );
      },
      onTapDown: (_) {
        setState(() {
          _isTapped = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isTapped = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isTapped = false;
        });
      },
      child: Card(
        color: _isTapped ? Colors.grey[300] : Colors.white,
        margin: EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: AppTextStyles.headline2),
              SizedBox(height: 8.0),
              Text(widget.description, style: AppTextStyles.bodyText1),
              SizedBox(height: 8.0),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < widget.difficulty ? Icons.star : Icons.star_border,
                    color: AppColors.primaryColor,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
