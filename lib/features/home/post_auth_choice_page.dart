import 'package:mambo/features/home/home_page.dart';
import 'package:mambo/features/home/log/log_list_page.dart';
import 'package:mambo/features/walk/quick_start_map_page.dart';
import 'package:mambo/features/walk/static_walk_summary_page.dart';
import 'package:mambo/l10n/l10n.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:mambo/services/demo_service.dart';
import 'package:mambo/services/locale_controller_scope.dart';
import 'package:mambo/services/locale_preference_service.dart';
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      minimumSize: const Size(double.infinity, 80),
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
                      context.l10n.startRecording,
                      style: AppTextStyles.buttonTextWhite,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      minimumSize: const Size(double.infinity, 80),
                      foregroundColor: AppColors.buttonTextColor,
                      backgroundColor: AppColors.primaryColor,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StaticWalkSummaryPage(),
                        ),
                      );
                    },
                    child: Text(
                      context.l10n.viewStaticSummary,
                      style: AppTextStyles.buttonTextWhite,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      minimumSize: const Size(double.infinity, 80),
                      foregroundColor: AppColors.buttonTextColor,
                      backgroundColor: AppColors.secondaryColor,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LogListPage(),
                        ),
                      );
                    },
                    child: Text(
                      context.l10n.viewMyRecords,
                      style: AppTextStyles.buttonTextWhite,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      side: const BorderSide(color: AppColors.primaryColor),
                    ),
                    icon: const Icon(
                      Icons.play_circle_outline,
                      color: AppColors.primaryColor,
                    ),
                    label: const Text(
                      'Try the Hong Kong demo',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      DemoService.instance
                        ..isDemo = true
                        ..reset();
                      // Force English for the whole demo experience.
                      LocaleControllerScope.of(
                        context,
                      ).setMode(AppLanguageMode.english);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        ),
                      );
                    },
                  ),
                ),
                if (AuthService().getCurrentUser()?.email == 'admin@mambo.com') ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: ButtonStyle(
                        minimumSize: WidgetStateProperty.all(
                          const Size(double.infinity, 80),
                        ),
                        foregroundColor: WidgetStateProperty.all(
                          AppColors.secondaryColor,
                        ),
                        shape: WidgetStateProperty.resolveWith<OutlinedBorder>((
                          Set<WidgetState> states,
                        ) {
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
                            side: const BorderSide(
                              color: AppColors.secondaryColor,
                            ),
                          );
                        }),
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
                        context.l10n.generateLegacyPlan,
                        style: TextStyle(color: AppColors.textColor),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
