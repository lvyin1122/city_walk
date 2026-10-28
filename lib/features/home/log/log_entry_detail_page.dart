import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';

import '../../../services/log_service.dart';
import 'log_map.dart';

/// One recorded moment: its photo, the question asked, the user's words,
/// where and when it was taken.
class LogEntryDetailPage extends StatelessWidget {
  final LogEntry entry;
  final Log? log;

  const LogEntryDetailPage({super.key, required this.entry, this.log});

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final timeStr = DateFormat('yyyy年M月d日 EEEE HH:mm', 'zh_CN').format(entry.timestamp.toLocal());
    final logs = [?log];
    final showMap = logPositions(logs, [entry]).isNotEmpty;
    final question = entry.question ?? '';
    final reflection = entry.description ?? '';
    final address = entry.address ?? '';

    Widget section(String title, Widget body) => Padding(
      padding: const EdgeInsets.only(bottom: FreshSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelMedium),
          const SizedBox(height: FreshSpace.sm),
          body,
        ],
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: FreshColors.riceWhite,
            leading: Padding(
              padding: const EdgeInsets.all(FreshSpace.sm),
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: FreshColors.paper.withValues(alpha: 0.92),
                  foregroundColor: FreshColors.ink,
                  side: FreshBorders.hairline,
                ),
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: '返回',
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                entry.imageUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => ColoredBox(
                      color: FreshColors.tint(FreshColors.line, 0.5),
                      child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 48)),
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              FreshSpace.page + 8,
              FreshSpace.xxl,
              FreshSpace.page,
              FreshSpace.section,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (question.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FreshSpace.xxl),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(question, style: text.titleMedium)),
                        const Botanical(kind: BotanicalKind.sprig, size: 48, opacity: 0.7),
                      ],
                    ),
                  ),
                if (reflection.isNotEmpty)
                  section('我的反思', Text(reflection, style: text.bodyLarge!.copyWith(height: 1.9))),
                if (address.isNotEmpty)
                  section(
                    '位置',
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined, size: 18, color: FreshColors.inkSoft),
                        const SizedBox(width: FreshSpace.sm),
                        Expanded(child: Text(address, style: text.bodyMedium)),
                      ],
                    ),
                  ),
                section(
                  '日期与时间',
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined, size: 18, color: FreshColors.inkSoft),
                      const SizedBox(width: FreshSpace.sm),
                      Text(timeStr, style: text.bodyMedium),
                    ],
                  ),
                ),
                if (showMap) section('地图', LogMap(logs: logs, entries: [entry])),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
