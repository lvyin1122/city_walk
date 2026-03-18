import 'package:mambo/features/auth/sign_in_page.dart';
import 'package:mambo/splash_screen.dart';
import 'package:mambo/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入的密码不一致')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // print the email and password
      print('Email: ${_emailController.text}');
      print('Password: ${_passwordController.text}');
      print('Name: ${_nameController.text}');
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        data: {'name': _nameController.text},
      );

      if (response.user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('注册成功！请登录以继续。')),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SignInPage()),
            (route) => false,
          );
        }
      }
    } catch (error) {
      String errorMessage = 'An error occurred during sign up';
      
      if (error is AuthException) {
        // Handle specific Supabase auth errors
        switch (error.message) {
          case 'User already registered':
            errorMessage = 'This email is already registered';
            break;
          case 'Invalid email':
            errorMessage = 'Please enter a valid email address';
            break;
          case 'Password should be at least 6 characters':
            errorMessage = 'Password must be at least 6 characters long';
            break;
          default:
            errorMessage = error.message;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
                    '创建你的\n账户',
                    style: AppTextStyles.headline1,
                  ),
                ),
                SizedBox(height: 20),

                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '昵称',
                    labelStyle: AppTextStyles.bodyText1,
                  ),
                ),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: '邮箱',
                    labelStyle: AppTextStyles.bodyText1,
                  ),
                ),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码',
                    labelStyle: AppTextStyles.bodyText1,
                  ),
                  obscureText: true,
                ),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: '确认密码',
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
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('注册', style: AppTextStyles.buttonTextWhite),
                  ),
                ),
                SizedBox(height: 60),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('已有账户？', style: AppTextStyles.bodyText1),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignInPage()),
                    );
                  },
                  child: Text('登录', style: AppTextStyles.buttonTextBlack),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
