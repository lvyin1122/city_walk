import 'package:mambo/features/home/home_page.dart';
import 'package:mambo/features/walk/quick_start_map_page.dart';
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class PostAuthChoicePage extends StatelessWidget {
  const PostAuthChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 100.0,
            bottom: 100.0,
            left: 40.0,
            right: 40.0,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  'What would you like to do?',
                  style: AppTextStyles.headline1,
                  textAlign: TextAlign.center,
                ),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                          foregroundColor: AppColors.buttonTextColor,
                          backgroundColor: AppColors.primaryColor,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QuickStartMapPage(),
                            ),
                          );
                        },
                        child: Text(
                          'Quick Start',
                          style: AppTextStyles.buttonTextWhite,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(
                            const Size(double.infinity, 50),
                          ),
                          foregroundColor:
                              WidgetStateProperty.all(AppColors.secondaryColor),
                          shape: WidgetStateProperty.resolveWith<OutlinedBorder>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.hovered)) {
                                return RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  side: const BorderSide(
                                    color: AppColors.hoverBorderColor,
                                  ),
                                );
                              }
                              return RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              );
                            },
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomePage(),
                            ),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'Generate New Walk Plan',
                          style: TextStyle(color: AppColors.textColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
