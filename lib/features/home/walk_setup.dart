import 'package:mambo/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class WalkSetup extends StatefulWidget {
  final List<bool> selectedKeywords;
  final double sliderValue;
  final Function(List<bool>) onKeywordsChanged;
  final Function(double) onSliderChanged;

  WalkSetup({
    required this.selectedKeywords,
    required this.sliderValue,
    required this.onKeywordsChanged,
    required this.onSliderChanged,
  });

  @override
  _WalkSetupState createState() => _WalkSetupState();
}

class _WalkSetupState extends State<WalkSetup> {
  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final currentUser = authService.getCurrentUser();

    return Padding(
      padding: const EdgeInsets.only(
        left: 40.0,
        right: 40.0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Welcome ${currentUser?.userMetadata?['name']}',
            style: AppTextStyles.headline1,
            textAlign: TextAlign.left,
          ),
          Text(
            'Start your journey here',
            style: AppTextStyles.headline1,
            textAlign: TextAlign.left,
          ),
          SizedBox(height: 40),
          Text(
            'Select your keywords',
            style: AppTextStyles.headline2,
            textAlign: TextAlign.left,
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: List<Widget>.generate(widget.selectedKeywords.length, (
              int index,
            ) {
              return ChoiceChip(
                label: Text('🌟 Keyword ${index + 1}'),
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
            'Select City Walk Time Duration',
            style: AppTextStyles.headline2,
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
        ],
      ),
    );
  }
}
