import 'dart:async';

import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/features/home/keywords.dart';
import 'package:mambo/features/home/walk_setup.dart';
import 'package:mambo/features/walk/data/walk_repository.dart';
import 'package:mambo/features/walk/quick_start_map_page.dart';
import 'package:mambo/features/walk/walk_map_page.dart';
import 'package:mambo/features/walk/walk_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
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

  final WalkRepository _repository = WalkRepository();
  List<bool> _selectedKeywords = List<bool>.filled(
    travelKeywords.length,
    false,
  );
  double _sliderValue = 30.0;
  int _selectedIndex = 1;
  bool _isLoading = false;
  List<String> _customKeywords = [];
  String? _inProgressWalkId;

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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _checkInProgressWalk() async {
    final user = AuthService().getCurrentUser();
    if (user == null) return;
    try {
      final walkId = await _repository.getInProgressWalkId(user.id);
      if (!mounted) return;
      setState(() {
        _inProgressWalkId = walkId;
      });
    } catch (e) {
      // Not being able to offer "resume" must not get in the way of starting
      // a new walk.
      debugPrint('Error checking in-progress walk: $e');
    }
  }

  Future<void> _continueInProgressWalk() async {
    final walkId = _inProgressWalkId;
    if (walkId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => WalkMapPage(walkId: walkId)),
    );
    // The walk may have been paused again or finished in the meantime.
    await _checkInProgressWalk();
  }

  /// Hides the card for now. The walk stays resumable and is offered again
  /// the next time the home page opens.
  void _dismissInProgressWalk() {
    setState(() {
      _inProgressWalkId = null;
    });
  }

  /// Gives up the walk in progress so that it is not offered again.
  Future<void> _abandonInProgressWalk() async {
    final walkId = _inProgressWalkId;
    if (walkId == null) return;
    try {
      await _repository.abandonWalk(walkId);
      if (!mounted) return;
      setState(() {
        _inProgressWalkId = null;
      });
    } catch (e) {
      _showMessage('操作失败：$e', isError: true);
    }
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
              children: [UserProfile(), _buildWalkTab(), const HistoryTab()],
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
        if (_inProgressWalkId != null) _buildInProgressCard(),
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
            onGenerate: _generateWalk,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    tooltip: '稍后再说',
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
                      onPressed: _abandonInProgressWalk,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '放弃这次',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  List<String> _selectedKeywordStrings() {
    return [
      for (int i = 0; i < _selectedKeywords.length; i++)
        if (_selectedKeywords[i]) travelKeywords[i],
      ..._customKeywords,
    ];
  }

  /// Returns the user's position, or null after telling them why it is not
  /// available.
  Future<GeoPoint?> _currentPosition() async {
    final location = Location();
    if (!await location.serviceEnabled() && !await location.requestService()) {
      _showMessage('请先打开手机的定位服务，才能生成你附近的路线。', isError: true);
      return null;
    }

    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
    }
    if (permission == PermissionStatus.deniedForever) {
      _showMessage('定位权限已被关闭。请到系统设置里允许 Mambo 使用定位。', isError: true);
      return null;
    }
    if (permission == PermissionStatus.denied) {
      _showMessage('需要定位权限才能生成你附近的路线。', isError: true);
      return null;
    }

    final data = await location.getLocation();
    return GeoPoint(data.latitude, data.longitude);
  }

  Future<void> _generateWalk() async {
    if (_isLoading) return;
    final keywords = _selectedKeywordStrings();
    if (keywords.isEmpty) {
      _showMessage('请至少选择或输入一个关键词');
      return;
    }
    final user = AuthService().getCurrentUser();
    if (user == null) {
      _showMessage('登录已失效，请重新登录', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final origin = await _currentPosition();
      if (origin == null) return;

      final walk = await _repository.generateWalk(
        userId: user.id,
        origin: origin,
        keywords: keywords,
        minutes: _sliderValue.round(),
      );

      if (!mounted) return;
      if (walk.stops.isEmpty) {
        _showMessage('这次没有找到合适的地点，换几个关键词再试试。', isError: true);
        return;
      }

      setState(() {
        _isLoading = false;
      });
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => WalkPreviewPage(walk: walk)),
      );
      // Back from the preview or from a paused walk.
      await _checkInProgressWalk();
    } on ApiException catch (e) {
      debugPrint('Walk generation failed: ${e.details}');
      _showMessage('生成步行路线失败：${e.userMessage}', isError: true);
    } catch (e) {
      debugPrint('Walk generation failed: $e');
      _showMessage('生成步行路线失败，请稍后重试。', isError: true);
    } finally {
      if (mounted && _isLoading) {
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
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '正在生成你的步行路线...',
                    style: AppTextStyles.headline3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '路线由 AI 现场生成，最长可能需要两分钟',
                    style: AppTextStyles.bodyText2.copyWith(
                      color: Colors.grey[600],
                    ),
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
