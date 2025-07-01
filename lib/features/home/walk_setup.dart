import 'package:mambo/features/home/keywords.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:flutter/material.dart';
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
                    'Welcome! ${currentUser?.userMetadata?['name']}',
                    style: AppTextStyles.headline2,
                    textAlign: TextAlign.left,
                  ),
                  Text(
                    'Start your journey here',
                    style: AppTextStyles.bodyText1,
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Select your keywords',
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
                        label: Text(travelKeywords[index]),
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
                    'Add custom keywords (comma-separated)',
                    style: AppTextStyles.bodyText1,
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _customKeywordsController,
                    decoration: InputDecoration(
                      hintText: 'e.g., local food, street art, architecture',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _handleCustomKeywordsChange,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Choose Walk Duration',
                    style: AppTextStyles.headline3,
                    textAlign: TextAlign.left,
                  ),
                  Slider(
                    value: widget.sliderValue,
                    min: 0,
                    max: 120,
                    divisions: 12,
                    label: '${widget.sliderValue.round()} mins',
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
                      '${widget.sliderValue.round()} mins',
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
