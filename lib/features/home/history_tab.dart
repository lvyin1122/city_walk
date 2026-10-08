import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'log/log_list_page.dart';
import 'walk_history/walk_history.dart';

/// History tab of the home page: generated walks and free-form records.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('历史', style: AppTextStyles.headline2),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            labelColor: AppColors.textColor,
            indicatorColor: AppColors.primaryColor,
            tabs: const [Tab(text: '漫步'), Tab(text: '记录')],
          ),
        ),
        body: const TabBarView(children: [WalkHistoryPage(), LogListPage()]),
      ),
    );
  }
}
