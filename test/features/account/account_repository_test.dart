import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/features/account/account_repository.dart';
import 'package:mambo/services/graphql_operations.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeletionClient extends ApiClient {
  DeletionClient(this.payload)
    : super(endpoint: Uri.parse('https://backend.test/graphql'));
  final Object? payload;
  Duration? timeoutUsed;
  String? document;
  Map<String, dynamic>? sentVariables;

  @override
  Future<Map<String, dynamic>> execute(
    String document, {
    Map<String, dynamic>? variables,
    Duration? timeout,
  }) async {
    this.document = document;
    timeoutUsed = timeout;
    sentVariables = variables;
    return {'deleteAccount': payload};
  }
}

class FakeService extends GraphQLService {
  FakeService(this.delete) : super(client: DeletionClient(null));
  final Future<void> Function() delete;

  @override
  Future<void> deleteAccount() => delete();
}

void main() {
  const retained = {
    'tutorial_seen': true,
    'walk_info_seen': true,
    'device_setting': 'keep',
  };
  const accountData = {
    'walk_summary_walk1': 'story',
    'walk_summary_walk2': 'story',
    'track_queue_walk1': 'pending',
    'scrapbook_gen_date': '2026-10-30',
    'scrapbook_gen_count': 2,
    'ai_consent_v1': true,
  };

  setUp(
    () => SharedPreferences.setMockInitialValues({...retained, ...accountData}),
  );

  test('server success precedes account cleanup and sign-out; device preferences survive', () async {
    var signedOut = false;
    final service = FakeService(() async {
      final preferences = await SharedPreferences.getInstance();
      for (final key in accountData.keys) {
        expect(preferences.containsKey(key), isTrue);
      }
    });
    await AccountRepository(
      service: service,
      signOut: () async {
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getKeys(), retained.keys.toSet());
        signedOut = true;
      },
    ).deleteAccount();

    final preferences = await SharedPreferences.getInstance();
    for (final entry in retained.entries) {
      expect(preferences.get(entry.key), entry.value);
    }
    expect(signedOut, isTrue);
  });

  test('backend failure preserves every local value and the session', () async {
    var signedOut = false;
    const failure = ApiNetworkException('offline');
    final repository = AccountRepository(
      service: FakeService(() async => throw failure),
      signOut: () async => signedOut = true,
    );
    await expectLater(repository.deleteAccount(), throwsA(same(failure)));
    final preferences = await SharedPreferences.getInstance();
    for (final entry in {...retained, ...accountData}.entries) {
      expect(preferences.get(entry.key), entry.value);
    }
    expect(signedOut, isFalse);
  });

  test('unexpected cleanup failure is exposed as an ApiException', () async {
    final repository = AccountRepository(
      service: FakeService(() async {}),
      signOut: () async => throw StateError('sign-out failed'),
    );
    await expectLater(repository.deleteAccount(), throwsA(isA<ApiException>()));
  });

  test('deletion uses the shared document with no arguments and a 60 second timeout', () async {
    final client = DeletionClient({'success': true});
    await GraphQLService(client: client).deleteAccount();
    expect(client.document, GraphQLOperations.deleteAccount);
    expect(client.sentVariables, isNull);
    expect(client.timeoutUsed, const Duration(seconds: 60));
  });

  test('deletion rejects false and malformed payloads', () async {
    for (final payload in [
      null,
      {},
      'true',
      {'success': false},
      {'success': 'true'},
    ]) {
      await expectLater(
        GraphQLService(client: DeletionClient(payload)).deleteAccount(),
        throwsA(isA<ApiResponseFormatException>()),
      );
    }
  });
}
