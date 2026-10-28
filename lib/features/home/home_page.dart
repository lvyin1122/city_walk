import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
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
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
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
        backgroundColor: isError ? Theme.of(context).colorScheme.errorContainer : null,
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
      body: PaperBackground(
        child: SafeArea(
          child: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: [const UserProfile(), _buildWalkTab(), const HistoryTab()],
              ),
              _buildLoadingOverlay(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: FreshBorders.hairline)),
        child: NavigationBar(
        selectedIndex: _selectedIndex,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(FreshSpace.page, FreshSpace.md, FreshSpace.page, 0),
      child: FreshCard(
        padding: const EdgeInsets.all(FreshSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk_outlined, color: FreshColors.skyText, size: 20),
                const SizedBox(width: FreshSpace.sm),
                Expanded(child: Text('继续你的步行', style: context.text.titleMedium)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: '稍后再说',
                  onPressed: _dismissInProgressWalk,
                ),
              ],
            ),
            Text('你有一项进行中的步行。是否继续上次的行程？', style: context.text.bodyMedium),
            const SizedBox(height: FreshSpace.lg),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _continueInProgressWalk,
                    child: const Text('继续步行'),
                  ),
                ),
                const SizedBox(width: FreshSpace.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _abandonInProgressWalk,
                    child: const Text('放弃这次'),
                  ),
                ),
              ],
            ),
          ],
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

    try {
      final data = await location.getLocation().timeout(
        const Duration(seconds: 15),
      );
      return GeoPoint(data.latitude, data.longitude);
    } on TimeoutException {
      if (!mounted) return null;
      _showMessage('暂时无法获取你的位置，请到开阔处再试一次。', isError: true);
      return null;
    }
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
    return IgnorePointer(
      ignoring: !_isLoading,
      child: AnimatedOpacity(
        opacity: _isLoading ? 1 : 0,
        duration: FreshMotion.of(context),
        curve: FreshMotion.curve,
        child: ColoredBox(
          color: FreshColors.riceWhite.withValues(alpha: 0.88),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: FreshSpace.xxl),
              child: FreshCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Botanical(kind: BotanicalKind.bamboo, size: 64),
                    const SizedBox(height: FreshSpace.lg),
                    const SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(minHeight: 1.5),
                    ),
                    const SizedBox(height: FreshSpace.lg),
                    Text(
                      '正在生成你的步行路线…',
                      style: context.text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: FreshSpace.sm),
                    Text(
                      '路线由 AI 现场生成，最长可能需要两分钟',
                      style: context.text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
