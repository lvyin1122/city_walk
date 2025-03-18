import 'package:mambo/features/walk/map_page.dart';
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class RecommendedWalksPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                WalkCard(
                  title: 'City Walk Plan 1',
                  description:
                      'Explore the historic downtown area with this easy walk.',
                  difficulty: 3,
                  keywords: ['History', 'Downtown'],
                ),
                WalkCard(
                  title: 'City Walk Plan 2',
                  description:
                      'A scenic walk through the city park and botanical gardens.',
                  difficulty: 2,
                  keywords: ['Nature', 'Scenic'],
                ),
                WalkCard(
                  title: 'City Walk Plan 3',
                  description:
                      'Challenge yourself with a hike up the city hills.',
                  difficulty: 4,
                  keywords: ['Hiking', 'Adventure'],
                ),
              ],
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
  final String description;
  final int difficulty;
  final List<String> keywords;

  WalkCard({
    required this.title,
    required this.description,
    required this.difficulty,
    required this.keywords,
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
            builder:
                (context) => MapPage(
                  title: widget.title,
                  description: widget.description,
                  difficulty: widget.difficulty,
                  keywords: widget.keywords,
                  taskTitle: widget.title,
                  taskDescription: widget.description,
                  totalTasks: 3,
                ),
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
              SizedBox(height: 8.0),
              Wrap(
                spacing: 8.0,
                children:
                    widget.keywords
                        .map((keyword) => Chip(label: Text(keyword)))
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
