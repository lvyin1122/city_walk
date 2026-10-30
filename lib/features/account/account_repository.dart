import 'dart:async';

import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deletes server data before clearing account-specific state on this device.
class AccountRepository {
  AccountRepository({GraphQLService? service, Future<void> Function()? signOut})
    : _service = service ?? GraphQLService(),
      _signOut = signOut ?? (() => AuthService().signOut());

  final GraphQLService _service;
  final Future<void> Function() _signOut;
  static const _localTimeout = Duration(seconds: 15);

  Future<void> deleteAccount() async {
    try {
      await _service.deleteAccount();
      final preferences = await SharedPreferences.getInstance().timeout(
        _localTimeout,
      );
      final keys = preferences.getKeys().where(
        (key) =>
            key.startsWith('walk_summary_') ||
            key.startsWith('track_queue_') ||
            key == 'scrapbook_gen_date' ||
            key == 'scrapbook_gen_count' ||
            key == 'ai_consent_v1',
      );
      final removed = await Future.wait(keys.map(preferences.remove))
          .timeout(_localTimeout);
      if (removed.any((success) => !success)) {
        throw const ApiResponseFormatException(
          'Could not clear local account data',
        );
      }
      await _signOut().timeout(_localTimeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiTimeoutException('Local account cleanup timed out');
    } catch (error) {
      throw ApiResponseFormatException(
        'Account cleanup failed (${error.runtimeType})',
      );
    }
  }
}
