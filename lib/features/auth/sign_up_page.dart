import 'package:city_walk/features/auth/sign_in_page.dart';
import 'package:city_walk/splash_screen.dart';
import 'package:city_walk/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
          onPressed: () {
            // jump to splash screen and clear the stack without animation
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation1, animation2) => SplashScreen(),
                transitionDuration: Duration.zero,
              ),
              (route) => false,
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(
          top: 100.0,
          bottom: 100.0,
          left: 40.0,
          right: 40.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Create \nyour account',
                    style: AppTextStyles.headline1,
                  ),
                ),
                SizedBox(height: 20),

                TextField(
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: AppTextStyles.bodyText1,
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: AppTextStyles.bodyText1,
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: AppTextStyles.bodyText1,
                  ),
                  obscureText: true,
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: AppTextStyles.bodyText1,
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      foregroundColor: AppColors.buttonTextColor,
                      backgroundColor: AppColors.primaryColor,
                    ),
                    onPressed: () {
                      // Handle sign up logic
                    },
                    child: Text('Sign Up', style: AppTextStyles.buttonTextWhite),
                  ),
                ),
                SizedBox(height: 60),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account?', style: AppTextStyles.bodyText1),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignInPage()),
                    );
                  },
                  child: Text('Sign In', style: AppTextStyles.buttonTextBlack),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
