import 'dart:async';

import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:mambo/features/home/keywords.dart';
import 'package:mambo/features/home/walk_setup.dart';
import 'package:mambo/features/walk/quick_start_map_page.dart';
import 'package:mambo/features/walk/walk_map_page.dart';
import 'package:mambo/features/walk/walk_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../services/graphql_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'history_tab.dart';
import 'tutorial_slides.dart';
import 'user_profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _tutorialSeenKey = 'tutorial_seen';

  List<bool> _selectedKeywords = List<bool>.filled(
    travelKeywords.length,
    false,
  );
  double _sliderValue = 30.0;
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
    _showTutorialOnFirstLaunch();
  }

  Future<void> _showTutorialOnFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tutorialSeenKey) ?? false) return;
    await prefs.setBool(_tutorialSeenKey, true);
    if (mounted) _openTutorial();
  }

  void _openTutorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const TutorialSlides(),
      ),
    );
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

      if (!mounted) return;
      setState(() {
        _inProgressWalkId = walkData?['Id'];
        _isCheckingInProgressWalk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingInProgressWalk = false;
      });
      // Silently handle errors for in-progress walk check
      debugPrint('Error checking in-progress walk: $e');
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

  void _startFreeRecord() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QuickStartMapPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: [
                UserProfile(),
                _buildWalkTab(),
                const HistoryTab(),
              ],
            ),
            _buildLoadingOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        indicatorColor: AppColors.primaryColor.withValues(alpha: 0.3),
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_walk_rounded),
            label: '漫步',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: '历史'),
        ],
      ),
    );
  }

  Widget _buildWalkTab() {
    return Column(
      children: [
        if (_inProgressWalkId != null && !_isCheckingInProgressWalk)
          _buildInProgressCard(),
        Expanded(
          child: WalkSetup(
            selectedKeywords: _selectedKeywords,
            sliderValue: _sliderValue,
            userName:
                AuthService().getCurrentUser()?.userMetadata?['name']
                    as String?,
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
            onGenerate: _generateWalks,
            onStartFreeRecord: _startFreeRecord,
            onShowHelp: _openTutorial,
          ),
        ),
      ],
    );
  }

  Widget _buildInProgressCard() {
    return Container(
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
                      '继续你的步行',
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
                '你有一项进行中的步行。是否继续上次的行程？',
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
                        '继续步行',
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
                        '重新开始',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请求超时，请重试。'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成步行路线失败：$e'),
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
                    '正在生成你的步行路线...',
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
