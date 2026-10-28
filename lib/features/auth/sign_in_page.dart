import 'package:flutter/material.dart';
import 'package:mambo/features/auth/sign_up_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
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
    return AuthScaffold(
      title: '登录你的账户',
      fields: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: '邮箱'),
        ),
        TextField(
          controller: _passwordController,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _isLoading ? null : _signIn(),
          decoration: const InputDecoration(labelText: '密码'),
          obscureText: true,
        ),
        AuthSubmitButton(label: '登录', loading: _isLoading, onPressed: _signIn),
      ],
      footer: AuthFooter(
        question: '还没有账户？',
        action: '注册',
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const SignUpPage()),
            ),
      ),
    );
  }
}
