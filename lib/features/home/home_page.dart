import 'package:mambo/features/home/keywords.dart';
import 'package:mambo/features/home/walk_setup.dart';
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:mambo/features/walk/walk_preview.dart';
import 'package:mambo/features/walk/walk_map_page.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';
import 'user_profile.dart';
import 'walk_history/walk_history.dart';
import 'package:location/location.dart';
import '../../services/graphql_service.dart';
import '../../services/auth_service.dart';
import 'dart:async';
import 'tutorial_slides.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<bool> _selectedKeywords = List<bool>.filled(
    travelKeywords.length,
    false,
  ); // Create a list with 15 false values
  double _sliderValue = 30.0; // Default slider value
  int _selectedIndex = 1;
  final GraphQLService _graphqlService = GraphQLService();
  bool _isLoading = false;
  List<String> _customKeywords = [];
  String? _inProgressWalkId;
  bool _isCheckingInProgressWalk = true;

  @override
  void initState() {
    super.initState();
    _checkInProgressWalk();
  }

  Future<void> _checkInProgressWalk() async {
    try {
      final user = AuthService().getCurrentUser();
      if (user == null) {
        setState(() {
          _isCheckingInProgressWalk = false;
        });
        return;
      }

      final result = await _graphqlService.getLatestInProgressWalk(userId: user.id);
      final walkData = result['data']['latestInProgressWalk'];
      
      setState(() {
        _inProgressWalkId = walkData?['Id'];
        _isCheckingInProgressWalk = false;
      });
    } catch (e) {
      setState(() {
        _isCheckingInProgressWalk = false;
      });
      // Silently handle errors for in-progress walk check
      print('Error checking in-progress walk: $e');
    }
  }

  void _continueInProgressWalk() {
    if (_inProgressWalkId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WalkMapPage(
            walkId: _inProgressWalkId!,
          ),
        ),
      );
    }
  }

  void _dismissInProgressWalk() {
    setState(() {
      _inProgressWalkId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Stack(
              children: [
                Visibility(
                  visible: _selectedIndex == 1,
                  child: Column(
                    children: [
                      // In-progress walk card
                      if (_inProgressWalkId != null && !_isCheckingInProgressWalk)
                        Container(
                          margin: const EdgeInsets.all(16),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.directions_walk,
                                        color: AppColors.primaryColor,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Continue Your Walk',
                                          style: AppTextStyles.headline3.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: _dismissInProgressWalk,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You have an in-progress walk. Would you like to continue where you left off?',
                                    style: AppTextStyles.bodyText1.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _continueInProgressWalk,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryColor,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Continue Walk',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _dismissInProgressWalk,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Start New',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Walk setup
                      Expanded(
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
                          onCustomKeywordsChanged: (List<String> keywords) {
                            setState(() {
                              _customKeywords = keywords;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Visibility(visible: _selectedIndex == 0, child: UserProfile()),
                Visibility(visible: _selectedIndex == 2, child: WalkHistoryPage()),
                _buildLoadingOverlay(),
              ],
            ),
          ),
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
        onTap: (int i) async {
          if (_selectedIndex == 1 && i == 1) {
            await _generateWalks();
          } else {
            setState(() {
              _selectedIndex = i;
            });
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => TutorialSlides(),
            ),
          );
        },
        child: Icon(Icons.help_outline),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  List<String> _getSelectedKeywordStrings() {
    List<String> selected = [];
    for (int i = 0; i < _selectedKeywords.length; i++) {
      if (_selectedKeywords[i]) {
        selected.add(travelKeywords[i]);
      }
    }
    selected.addAll(_customKeywords);
    return selected;
  }

  Future<void> _generateWalks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled');
        }
      }
      LocationData locationData = await location.getLocation();
      final user = AuthService().getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      final response = await _graphqlService.generateWalk(
        userId: user.id,
        // TEST locations
        // location: "22.282012124798037, 114.15839373519509",
        location: "${locationData.latitude}, ${locationData.longitude}",
        keywords: _getSelectedKeywordStrings(),
        duration: _sliderValue,
      ).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw TimeoutException('Request timed out after 2 minutes');
        },
      );

      // Close the loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      if (response['data']?['generateWalkWithGpt']?['walk'] != null) {
        final walk = response['data']['generateWalkWithGpt']['walk'];
        // add index to each location
        List<dynamic> locations = walk['locations'].map((location) => {
          ...location,
          'index': walk['locations'].indexOf(location),
        }).toList();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WalkPreviewPage(
              title: walk['title'],
              description: walk['description'],
              walkId: walk['Id'],
              locations: locations,
              estimatedMinutes: walk['totalDuration'],
            ),
          ),
        );
      } else {
        throw Exception('Invalid response format');
      }
    } on TimeoutException {
      if (!mounted) return;
      // Close the loading dialog if it's still showing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request timed out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Close the loading dialog if it's still showing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate walk: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLoadingOverlay() {
    return Visibility(
      visible: _isLoading,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: EdgeInsets.symmetric(horizontal: 40),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Generating your walk plans...',
                    style: AppTextStyles.headline3,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
