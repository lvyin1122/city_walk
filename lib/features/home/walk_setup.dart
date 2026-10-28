import 'package:mambo/features/home/keywords.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:mambo/l10n/l10n.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class WalkSetup extends StatefulWidget {
  final List<bool> selectedKeywords;
  final double sliderValue;
  final Function(List<bool>) onKeywordsChanged;
  final Function(double) onSliderChanged;
  final Function(List<String>) onCustomKeywordsChanged;

  WalkSetup({
    required this.selectedKeywords,
    required this.sliderValue,
    required this.onKeywordsChanged,
    required this.onSliderChanged,
    required this.onCustomKeywordsChanged,
  });

  @override
  _WalkSetupState createState() => _WalkSetupState();
}

class _WalkSetupState extends State<WalkSetup> {
  final TextEditingController _customKeywordsController =
      TextEditingController();
  List<String> _customKeywords = [];

  @override
  void dispose() {
    _customKeywordsController.dispose();
    super.dispose();
  }

  void _handleCustomKeywordsChange(String value) {
    setState(() {
      _customKeywords =
          value
              .split(',')
              .map((keyword) => keyword.trim())
              .where((keyword) => keyword.isNotEmpty)
              .toList();
      widget.onCustomKeywordsChanged(_customKeywords);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final currentUser = authService.getCurrentUser();
    final keywordLabels = travelKeywordLabels(
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh'),
    );

    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(left: 40.0, right: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.welcomeUser(
                      currentUser?.userMetadata?['name']?.toString() ?? '',
                    ),
                    style: AppTextStyles.headline2,
                    textAlign: TextAlign.left,
                  ),
                  Text(
                    context.l10n.startJourneyHere,
                    style: AppTextStyles.bodyText1,
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 20),
                  Text(
                    context.l10n.selectKeywords,
                    style: AppTextStyles.headline3,
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List<Widget>.generate(travelKeywords.length, (
                      int index,
                    ) {
                      return ChoiceChip(
                        label: Text(keywordLabels[index]),
                        selected: widget.selectedKeywords[index],
                        onSelected: (bool selected) {
                          setState(() {
                            widget.selectedKeywords[index] = selected;
                          });
                          widget.onKeywordsChanged(widget.selectedKeywords);
                        },
                        selectedColor: AppColors.primaryColor,
                        backgroundColor: Colors.grey[200],
                      );
                    }),
                  ),
                  SizedBox(height: 20),
                  Text(
                    context.l10n.addCustomKeywords,
                    style: AppTextStyles.bodyText1,
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _customKeywordsController,
                    decoration: InputDecoration(
                      hintText: context.l10n.customKeywordsHint,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _handleCustomKeywordsChange,
                  ),
                  SizedBox(height: 20),
                  Text(
                    context.l10n.selectWalkDuration,
                    style: AppTextStyles.headline3,
                    textAlign: TextAlign.left,
                  ),
                  Slider(
                    value: widget.sliderValue,
                    min: 0,
                    max: 120,
                    divisions: 12,
                    label: context.l10n.minutes(widget.sliderValue.round()),
                    onChanged: (double value) {
                      setState(() {
                        widget.onSliderChanged(value);
                      });
                    },
                    activeColor: AppColors.primaryColor,
                    inactiveColor: Colors.grey,
                  ),
                  Center(
                    child: Text(
                      context.l10n.minutes(widget.sliderValue.round()),
                      style: AppTextStyles.headline2,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
