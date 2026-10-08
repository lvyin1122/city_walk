import 'package:flutter/material.dart';
import 'package:mambo/features/auth/sign_up_page.dart';
import 'package:mambo/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'auth_error_messages.dart';
import 'auth_form_layout.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('请输入邮箱和密码');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(email: email, password: password);

      if (mounted) {
        // The root route decides what a signed-in user sees.
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on AuthException catch (error) {
      _showMessage(signInErrorMessage(error));
    } catch (error) {
      debugPrint('Sign in failed: $error');
      _showMessage('登录失败，请检查网络后重试');
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
      body: AuthFormLayout(
        form: AutofillGroup(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Text('登录你的\n账户', style: AppTextStyles.headline1),
              ),
              const SizedBox(height: 60),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: '邮箱',
                  labelStyle: AppTextStyles.bodyText1,
                ),
              ),
              TextField(
                controller: _passwordController,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _isLoading ? null : _signIn(),
                decoration: InputDecoration(
                  labelText: '密码',
                  labelStyle: AppTextStyles.bodyText1,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    foregroundColor: AppColors.buttonTextColor,
                    backgroundColor: AppColors.primaryColor,
                  ),
                  onPressed: _isLoading ? null : _signIn,
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('登录', style: AppTextStyles.buttonTextWhite),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('还没有账户？', style: AppTextStyles.bodyText1),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpPage()),
                );
              },
              child: Text('注册', style: AppTextStyles.buttonTextBlack),
            ),
          ],
        ),
      ),
    );
  }
}
