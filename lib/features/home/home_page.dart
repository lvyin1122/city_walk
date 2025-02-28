import 'package:city_walk/features/home/walk_setup.dart';
import 'package:city_walk/features/walk/recommended_walks_page.dart';
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';
import 'user_profile.dart';
import 'walk_history/walk_history.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<bool> _selectedKeywords = List<bool>.filled(
    15,
    false,
  ); // Create a list with 15 false values
  double _sliderValue = 30.0; // Default slider value
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Visibility(
            visible: _selectedIndex == 1,
            child: WalkSetup(
              selectedKeywords: _selectedKeywords,
              sliderValue: _sliderValue,
              onKeywordsChanged: (List<bool> keywords) {
                setState(() {
                  _selectedKeywords = keywords;
                });
              },
              onSliderChanged: (double value) {
                setState(() {
                  _sliderValue = value;
                });
              },
            ),
          ),
          Visibility(visible: _selectedIndex == 0, child: UserProfile()),
          Visibility(visible: _selectedIndex == 2, child: WalkHistoryPage()),
        ],
      ),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.fixedCircle,
        backgroundColor: AppColors.primaryColor,
        items: [
          TabItem(icon: Icons.person),
          TabItem(
            icon:
                _selectedIndex == 1
                    ? Icons.directions_walk_rounded
                    : Icons.home,
          ),
          TabItem(icon: Icons.history),
        ],
        initialActiveIndex: 1,
        onTap: (int i) {
          if (_selectedIndex == 1 && i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RecommendedWalksPage()),
            );
          } else {
            setState(() {
              _selectedIndex = i;
            });
          }
        },
      ),
    );
  }
}
