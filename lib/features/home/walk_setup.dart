import 'package:flutter/material.dart';
import 'package:mambo/features/home/keywords.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 40.0, right: 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                Expanded(
                  child: Text(_greeting, style: AppTextStyles.headline2),
                ),
                if (widget.onShowHelp != null)
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    tooltip: '使用说明',
                    onPressed: widget.onShowHelp,
                  ),
              ],
            ),
            Text('从这里开始你的旅程', style: AppTextStyles.bodyText1),
            const SizedBox(height: 20),
            Text('选择你的关键词', style: AppTextStyles.headline3),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: List<Widget>.generate(travelKeywords.length, (
                int index,
              ) {
                return ChoiceChip(
                  label: Text(travelKeywords[index]),
                  selected: widget.selectedKeywords[index],
                  onSelected: (bool selected) {
                    final updated = List<bool>.of(widget.selectedKeywords);
                    updated[index] = selected;
                    widget.onKeywordsChanged(updated);
                  },
                  selectedColor: AppColors.primaryColor,
                  backgroundColor: Colors.grey[200],
                );
              }),
            ),
            const SizedBox(height: 20),
            Text('添加自定义关键词（用逗号或顿号分隔）', style: AppTextStyles.bodyText1),
            const SizedBox(height: 10),
            TextField(
              controller: _customKeywordsController,
              decoration: const InputDecoration(
                hintText: '例如：本地美食、街头艺术、建筑',
                border: OutlineInputBorder(),
              ),
              onChanged:
                  (value) => widget.onCustomKeywordsChanged(
                    parseCustomKeywords(value),
                  ),
            ),
            const SizedBox(height: 20),
            Text('选择漫步时长', style: AppTextStyles.headline3),
            Slider(
              value: widget.sliderValue,
              min: minWalkMinutes,
              max: maxWalkMinutes,
              divisions: ((maxWalkMinutes - minWalkMinutes) / 10).round(),
              label: '${widget.sliderValue.round()} 分钟',
              onChanged: widget.onSliderChanged,
              activeColor: AppColors.primaryColor,
              inactiveColor: Colors.grey,
            ),
            Center(
              child: Text(
                '${widget.sliderValue.round()} 分钟',
                style: AppTextStyles.headline2,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  foregroundColor: AppColors.buttonTextColor,
                  backgroundColor: AppColors.primaryColor,
                ),
                onPressed: widget.onGenerate,
                icon: const Icon(Icons.auto_awesome),
                label: Text('生成路线', style: AppTextStyles.buttonTextWhite),
              ),
            ),
            if (widget.onStartFreeRecord != null)
              Center(
                child: TextButton(
                  onPressed: widget.onStartFreeRecord,
                  child: Text(
                    '不需要路线？直接开始记录',
                    style: TextStyle(color: AppColors.textColor),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
