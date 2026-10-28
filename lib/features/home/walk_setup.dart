import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:flutter/material.dart';
import 'package:mambo/features/home/keywords.dart';

/// Shortest and longest walk the user can ask for, in minutes.
const double minWalkMinutes = 10;
const double maxWalkMinutes = 120;

class WalkSetup extends StatefulWidget {
  final List<bool> selectedKeywords;
  final double sliderValue;
  final String? userName;
  final ValueChanged<List<bool>> onKeywordsChanged;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<List<String>> onCustomKeywordsChanged;
  final VoidCallback onGenerate;
  final VoidCallback? onStartFreeRecord;
  final VoidCallback? onShowHelp;

  const WalkSetup({
    super.key,
    required this.selectedKeywords,
    required this.sliderValue,
    required this.onKeywordsChanged,
    required this.onSliderChanged,
    required this.onCustomKeywordsChanged,
    required this.onGenerate,
    this.userName,
    this.onStartFreeRecord,
    this.onShowHelp,
  });

  @override
  State<WalkSetup> createState() => _WalkSetupState();
}

class _WalkSetupState extends State<WalkSetup> {
  final TextEditingController _customKeywordsController =
      TextEditingController();

  @override
  void dispose() {
    _customKeywordsController.dispose();
    super.dispose();
  }

  String get _greeting {
    final name = widget.userName?.trim();
    return name == null || name.isEmpty ? '欢迎！' : '欢迎，$name！';
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final minutes = widget.sliderValue.round();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        FreshSpace.page + 8,
        FreshSpace.xxl,
        FreshSpace.page,
        FreshSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FreshHeading(
                  _greeting,
                  subtitle: '从这里开始你的旅程',
                  botanical: BotanicalKind.sprig,
                ),
              ),
              if (widget.onShowHelp != null)
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: '使用说明',
                  onPressed: widget.onShowHelp,
                ),
            ],
          ),
          const SizedBox(height: FreshSpace.section * 0.6),
          Text('选择你的关键词', style: text.titleMedium),
          const SizedBox(height: FreshSpace.md),
          Wrap(
            spacing: FreshSpace.sm,
            runSpacing: FreshSpace.sm,
            children: [
              for (final (index, keyword) in travelKeywords.indexed)
                ChoiceChip(
                  label: Text(keyword),
                  selected: widget.selectedKeywords[index],
                  showCheckmark: false,
                  onSelected: (bool selected) {
                    final updated = List<bool>.of(widget.selectedKeywords);
                    updated[index] = selected;
                    widget.onKeywordsChanged(updated);
                  },
                ),
            ],
          ),
          const SizedBox(height: FreshSpace.xl),
          TextField(
            controller: _customKeywordsController,
            decoration: const InputDecoration(
              labelText: '自定义关键词',
              hintText: '例如：本地美食、街头艺术、建筑',
              helperText: '用逗号或顿号分隔',
            ),
            onChanged:
                (value) =>
                    widget.onCustomKeywordsChanged(parseCustomKeywords(value)),
          ),
          const SizedBox(height: FreshSpace.section * 0.5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('选择漫步时长', style: text.titleMedium),
              const Spacer(),
              Text('$minutes', style: text.headlineMedium),
              const SizedBox(width: FreshSpace.xs),
              Text('分钟', style: text.bodyMedium),
            ],
          ),
          Slider(
            value: widget.sliderValue,
            min: minWalkMinutes,
            max: maxWalkMinutes,
            divisions: ((maxWalkMinutes - minWalkMinutes) / 10).round(),
            label: '$minutes 分钟',
            semanticFormatterCallback: (value) => '${value.round()} 分钟',
            onChanged: widget.onSliderChanged,
          ),
          const SizedBox(height: FreshSpace.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onGenerate,
              icon: const Icon(Icons.auto_awesome_outlined, size: 20),
              label: const Text('生成路线'),
            ),
          ),
          if (widget.onStartFreeRecord != null)
            Padding(
              padding: const EdgeInsets.only(top: FreshSpace.sm),
              child: Center(
                child: TextButton(
                  onPressed: widget.onStartFreeRecord,
                  child: const Text('不需要路线？直接开始记录'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
