import 'package:mambo/features/home/home_page.dart';
import 'package:mambo/features/auth/sign_up_page.dart';
import 'package:mambo/splash_screen.dart';
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../home/tutorial_slides.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    
    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => TutorialSlides(
              onFinish: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => HomePage()),
                  (route) => false,
                );
              },
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textColor, size: 30),
          onPressed: () {
            // jump to splash screen and clear the stack
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
                    'Sign in to \nyour account',
                    style: AppTextStyles.headline1,
                  ),
                ),
                SizedBox(height: 100),

                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: AppTextStyles.bodyText1,
                  ),
                ),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Sign In', style: AppTextStyles.buttonTextWhite),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Don\'t have an account?', style: AppTextStyles.bodyText1),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignUpPage()),
                    );
                  },
                  child: Text('Sign Up', style: AppTextStyles.buttonTextBlack),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
