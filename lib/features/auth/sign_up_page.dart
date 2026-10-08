import 'package:flutter/material.dart';
import 'package:mambo/features/auth/sign_in_page.dart';
import 'package:mambo/splash_screen.dart';
import 'package:mambo/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_text_styles.dart';
import 'auth_error_messages.dart';
import 'auth_form_layout.dart';

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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('请填写昵称、邮箱和密码');
      return;
    }
    if (password.length < 6) {
      _showMessage('密码至少需要 6 位');
      return;
    }
    if (password != _confirmPasswordController.text) {
      _showMessage('两次输入的密码不一致');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      if (!mounted) return;

      if (response.session != null) {
        // Signed in already: the root route shows the home page.
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else if (response.user != null) {
        // The project requires e-mail confirmation before the first sign-in.
        _showMessage('注册成功！请查收验证邮件，然后登录。');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SignInPage()),
          (route) => false,
        );
      }
    } on AuthException catch (error) {
      _showMessage(signUpErrorMessage(error));
    } catch (error) {
      debugPrint('Sign up failed: $error');
      _showMessage('注册失败，请检查网络后重试');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      body: AuthFormLayout(
        form: AutofillGroup(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Text('创建你的\n账户', style: AppTextStyles.headline1),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.nickname],
                decoration: InputDecoration(
                  labelText: '昵称',
                  labelStyle: AppTextStyles.bodyText1,
                ),
              ),
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
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: '密码（至少 6 位）',
                  labelStyle: AppTextStyles.bodyText1,
                ),
                obscureText: true,
              ),
              TextField(
                controller: _confirmPasswordController,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _isLoading ? null : _signUp(),
                decoration: InputDecoration(
                  labelText: '确认密码',
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
                  onPressed: _isLoading ? null : _signUp,
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('注册', style: AppTextStyles.buttonTextWhite),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('已有账户？', style: AppTextStyles.bodyText1),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInPage()),
                );
              },
              child: Text('登录', style: AppTextStyles.buttonTextBlack),
            ),
          ],
        ),
      ),
    );
  }
}
