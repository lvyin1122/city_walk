import 'package:flutter/material.dart';

import 'log/log_list_page.dart';
import 'walk_history/walk_history.dart';

/// History tab of the home page: generated walks and free-form records.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _HistoryBar(),
        body: TabBarView(children: [WalkHistoryPage(), LogListPage()]),
      ),
    );
  }
}

class _HistoryBar extends StatelessWidget implements PreferredSizeWidget {
  const _HistoryBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight + 16);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('历史'),
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight + 16,
      titleSpacing: 36,
      bottom: const TabBar(tabs: [Tab(text: '漫步'), Tab(text: '记录')]),
    );
  }
}
