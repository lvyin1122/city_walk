import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/features/auth/auth_error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('signInErrorMessage', () {
    test('wrong credentials', () {
      expect(
        signInErrorMessage(
          const AuthException(
            'Invalid login credentials',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        ),
        '邮箱或密码不正确',
      );
    });

    test('unconfirmed e-mail, recognised by message alone', () {
      expect(
        signInErrorMessage(
          const AuthException('Email not confirmed', statusCode: '400'),
        ),
        contains('尚未验证'),
      );
    });

    test('request that never reached the server', () {
      expect(
        signInErrorMessage(const AuthException('SocketException')),
        contains('网络'),
      );
    });

    test('never exposes the raw exception text', () {
      final message = signInErrorMessage(
        const AuthException('Database error querying schema', statusCode: '500'),
      );
      expect(message, isNot(contains('Database')));
    });
  });

  group('signUpErrorMessage', () {
    test('existing account', () {
      expect(
        signUpErrorMessage(
          const AuthException(
            'User already registered',
            statusCode: '422',
            code: 'user_already_exists',
          ),
        ),
        contains('已注册'),
      );
    });

    test('weak password', () {
      expect(
        signUpErrorMessage(
          const AuthException(
            'Password should be at least 6 characters.',
            statusCode: '422',
            code: 'weak_password',
          ),
        ),
        contains('6 位'),
      );
    });

    test('rate limited', () {
      expect(
        signUpErrorMessage(
          const AuthException(
            'Email rate limit exceeded',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        ),
        contains('频繁'),
      );
    });
  });
}
