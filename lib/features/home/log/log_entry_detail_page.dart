import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/log_service.dart';
import 'log_map.dart';

class LogEntryDetailPage extends StatelessWidget {
  final LogEntry entry;
  final Log? log;

  const LogEntryDetailPage({super.key, required this.entry, this.log});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        DateFormat('yyyy年M月d日 EEEE HH:mm', 'zh_CN').format(entry.timestamp.toLocal());
    final logs = [?log];
    final showMap = logPositions(logs, [entry]).isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back, color: FreshColors.body, size: 22),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                entry.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: FreshColors.line,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 64),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Question (no section title)
                if (entry.question != null && entry.question!.isNotEmpty) ...[
                  Text(
                    entry.question!,
                    style: context.text.bodyLarge!.copyWith(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Reflection text
                if (entry.description != null && entry.description!.isNotEmpty) ...[
                  Text(
                    '我的反思',
                    style: context.text.titleMedium!.copyWith(
                      color: FreshColors.skyText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.description!,
                    style: context.text.bodyLarge!.copyWith(
                      fontSize: 17,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Address
                if (entry.address != null && entry.address!.isNotEmpty) ...[
                  Text(
                    '位置',
                    style: context.text.titleMedium!.copyWith(
                      color: FreshColors.skyText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: FreshColors.inkSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.address!,
                          style: context.text.bodyLarge!.copyWith(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                // Timestamp
                Text(
                    '日期与时间',
                  style: context.text.titleMedium!.copyWith(
                    color: FreshColors.skyText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: FreshColors.inkSoft,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: context.text.bodyMedium!.copyWith(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Map
                if (showMap) ...[
                  Text(
                    '地图',
                    style: context.text.titleMedium!.copyWith(
                      color: FreshColors.skyText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LogMap(logs: logs, entries: [entry]),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
