import 'package:flutter/material.dart';
import 'package:mambo/features/home/keywords.dart';
import 'package:mambo/features/home/walk_history/walk_history.dart';
import 'package:mambo/features/home/walk_setup.dart';
import 'package:mambo/features/walk/widgets/summary_sections.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';

import 'demo_data.dart';

/// App screens rendered from the real widgets with demo data. Each mirrors
/// the layout of the page it stands for; only data loading is left out.

/// The bottom navigation of `HomePage` (`lib/features/home/home_page.dart`).
Widget _homeNavigation(int selectedIndex) => DecoratedBox(
  decoration: BoxDecoration(border: Border(top: FreshBorders.hairline)),
  child: NavigationBar(
    selectedIndex: selectedIndex,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: '我的',
      ),
      NavigationDestination(icon: Icon(Icons.directions_walk_rounded), label: '漫步'),
      NavigationDestination(icon: Icon(Icons.history), label: '历史'),
    ],
  ),
);

/// Slot 01: the walk tab of the home page.
Widget setupScreen() {
  final selected = [
    for (final keyword in travelKeywords)
      keyword.contains('街头文化') || keyword.contains('美食') || keyword.contains('历史遗迹'),
  ];
  return Scaffold(
    body: PaperBackground(
      child: SafeArea(
        child: WalkSetup(
          selectedKeywords: selected,
          sliderValue: 90,
          userName: '小林',
          onKeywordsChanged: (_) {},
          onSliderChanged: (_) {},
          onCustomKeywordsChanged: (_) {},
          onGenerate: () {},
          onShowHelp: () {},
        ),
      ),
    ),
    bottomNavigationBar: _homeNavigation(1),
  );
}

/// Slot 05: the summary of a just-finished walk (`walk_summary.dart`). The
/// map section is left out; it is a native view that only a device capture
/// can show.
Widget summaryScreen({required List<String> photoUrls}) {
  final walk = sheungWanWalk(photoUrls: photoUrls);
  const gap = SizedBox(height: FreshSpace.xxl);
  return Scaffold(
    body: PaperBackground(
      child: SafeArea(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(FreshSpace.page, 0, FreshSpace.page, FreshSpace.xxl),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: FreshSpace.xl, bottom: FreshSpace.xl),
              child: FreshHeading(
                '恭喜，你完成了这次漫步',
                subtitle: walk.title,
                botanical: BotanicalKind.blossom,
              ),
            ),
            WalkStatsCard(walk: walk),
            gap,
            WalkStoryCard(story: sheungWanStory, failed: false, onRetry: () {}),
            if (photoUrls.isNotEmpty) ...[
              gap,
              PhotoGrid(title: '心动瞬间', photoUrls: photoUrls, onTap: (_) {}),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Slot 06: the history tab (`history_tab.dart` with free record off).
Widget historyScreen() {
  final walks = historyWalks();
  return Scaffold(
    body: PaperBackground(
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('历史'),
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            toolbarHeight: kToolbarHeight + 16,
            titleSpacing: 36,
          ),
          body: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(FreshSpace.page, FreshSpace.xl, FreshSpace.page, FreshSpace.xxl),
            itemCount: walks.length,
            separatorBuilder: (_, _) => const SizedBox(height: FreshSpace.md),
            itemBuilder: (context, index) => WalkHistoryCard(walk: walks[index]),
          ),
        ),
      ),
    ),
    bottomNavigationBar: _homeNavigation(2),
  );
}
