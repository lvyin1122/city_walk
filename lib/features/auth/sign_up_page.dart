import 'package:flutter/material.dart';
import 'package:mambo/features/auth/sign_in_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_error_messages.dart';
import 'auth_form_layout.dart';
import 'package:mambo/widgets/botanical.dart';

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
    return AuthScaffold(
      title: '创建你的账户',
      botanical: BotanicalKind.blossom,
      fields: [
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.nickname],
          decoration: const InputDecoration(labelText: '昵称'),
        ),
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
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: '密码（至少 6 位）'),
          obscureText: true,
        ),
        TextField(
          controller: _confirmPasswordController,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _isLoading ? null : _signUp(),
          decoration: const InputDecoration(labelText: '确认密码'),
          obscureText: true,
        ),
        AuthSubmitButton(label: '注册', loading: _isLoading, onPressed: _signUp),
      ],
      footer: AuthFooter(
        question: '已有账户？',
        action: '登录',
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const SignInPage()),
            ),
      ),
    );
  }
}
