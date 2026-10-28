import 'package:mambo/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:mambo/l10n/l10n.dart';
import 'features/auth/sign_up_page.dart';
import 'features/auth/sign_in_page.dart';
import 'features/home/home_page.dart';
import 'services/demo_service.dart';
import 'services/locale_controller_scope.dart';
import 'services/locale_preference_service.dart';
import 'theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
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
                  context.l10n.welcomeMamboWalk,
                  style: AppTextStyles.headline1,
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
                          minimumSize: Size(double.infinity, 50),
                          foregroundColor: AppColors.buttonTextColor,
                          backgroundColor: AppColors.primaryColor,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SignUpPage()),
                          );
                        },
                        child: Text(
                          context.l10n.iAmNewUser,
                          style: AppTextStyles.buttonTextWhite,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(Size(double.infinity, 50)),
                          foregroundColor: WidgetStateProperty.all(AppColors.secondaryColor),
                          shape: WidgetStateProperty.resolveWith<OutlinedBorder>((Set<WidgetState> states) {
                            if (states.contains(WidgetState.hovered)) {
                              return RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: BorderSide(color: AppColors.hoverBorderColor),
                              );
                            }
                            return RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            );
                          }),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SignInPage()),
                          );
                        },
                        child: Text(
                          context.l10n.iHaveAccount,
                          style: TextStyle(color: AppColors.textColor),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          side: BorderSide(color: AppColors.primaryColor),
                        ),
                        icon: Icon(
                          Icons.play_circle_outline,
                          color: AppColors.primaryColor,
                        ),
                        label: Text(
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
