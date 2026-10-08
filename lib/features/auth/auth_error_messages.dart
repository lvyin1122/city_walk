import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a Supabase sign-in failure into a message the user can act on.
String signInErrorMessage(AuthException error) {
  final message = error.message.toLowerCase();
  if (error.code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
    return '邮箱或密码不正确';
  }
  if (error.code == 'email_not_confirmed' ||
      message.contains('email not confirmed')) {
    return '邮箱尚未验证，请先查收验证邮件';
  }
  return _commonMessage(error) ?? '登录失败，请稍后重试';
}

/// Turns a Supabase sign-up failure into a message the user can act on.
String signUpErrorMessage(AuthException error) {
  final message = error.message.toLowerCase();
  if (error.code == 'user_already_exists' ||
      error.code == 'email_exists' ||
      message.contains('already registered')) {
    return '该邮箱已注册，请直接登录';
  }
  if (error.code == 'weak_password' || message.contains('password should')) {
    return '密码至少需要 6 位';
  }
  if (error.code == 'validation_failed' || message.contains('invalid')) {
    return '请输入有效的邮箱地址';
  }
  return _commonMessage(error) ?? '注册失败，请稍后重试';
}

String? _commonMessage(AuthException error) {
  final code = error.code ?? '';
  if (code.contains('rate_limit')) return '操作太频繁，请稍后再试';
  // No status code means the request never reached the server.
  if (error.statusCode == null) return '网络连接失败，请检查网络后重试';
  return null;
}
