import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/app/app_version.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/services/graphql_operations.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:mambo/theme/app_theme.dart';

void main() {
  test('compares numeric versions and ignores metadata', () {
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0.0+5', '1.0.0'), 0);
    expect(compareVersions('1.0.1-beta', '1.0.1'), 0);
    expect(compareVersions('1.word.1', '1.0.1'), 0);
    expect(compareVersions(' v1.2.0 ', '1.2'), 0);
    expect(compareVersions('', '0.0.0'), 0);
  });

  test('requires an update only below a nonempty minimum', () async {
    for (final (current, minimum, expected) in [
      ('1.0.0', '1.0.1', true),
      ('1.0.0', '1.0.0', false),
      ('1.1', '1.0.0', false),
      ('1.0.0', '', false),
      ('1.0.0', '  ', false),
    ]) {
      expect(await isUpdateRequired(
        currentVersion: () async => current,
        minimumVersion: () async => minimum,
      ), expected);
    }
  });

  test('errors from either version source allow startup', () async {
    Future<String> fail() => throw StateError('unavailable');
    expect(await isUpdateRequired(
      currentVersion: () async => '1.0', minimumVersion: fail,
    ), isFalse);
    expect(await isUpdateRequired(
      currentVersion: fail, minimumVersion: () async => '9.0',
    ), isFalse);
  });

  testWidgets('a stalled minimum permits startup within five seconds', (tester) async {
    bool? result;
    unawaited(isUpdateRequired(
      currentVersion: () async => '1.0',
      minimumVersion: () => Completer<String>().future,
    ).then((value) => result = value));
    await tester.pump(const Duration(seconds: 6));
    expect(result, isFalse);
  });

  testWidgets('a stalled package read shares the same deadline', (tester) async {
    bool? result;
    unawaited(isUpdateRequired(
      currentVersion: () => Completer<String>().future,
      minimumVersion: () async => '9.0',
    ).then((value) => result = value));
    await tester.pump(const Duration(seconds: 6));
    expect(result, isFalse);
  });

  test('minimum version uses the shared GraphQL document and typed field', () async {
    final service = GraphQLService.public(client: ApiClient(
      endpoint: Uri.https('backend.test', '/graphql'),
      httpClient: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect((jsonDecode(request.body) as Map)['query'], GraphQLOperations.appConfig);
        return http.Response('{"data":{"appConfig":{"minimumVersion":"9.0.0"}}}', 200);
      }),
    ));
    expect(await service.minimumAppVersion(), '9.0.0');
  });

  testWidgets('update screen explains the requirement without an empty link', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(), home: const UpdateRequiredScreen(),
    ));
    expect(find.text('请更新 Mambo'), findsOneWidget);
    expect(find.text('这个版本已经停止支持，请到应用商店更新到最新版本后继续使用。'), findsOneWidget);
    expect(find.text('前往更新'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
