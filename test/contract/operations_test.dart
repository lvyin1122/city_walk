import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/services/graphql_operations.dart';

/// The GraphQL documents the app sends, exported for the backend.
///
/// The backend's `tests/test_contract.py` validates `operations.json` against
/// its schema. When an operation changes, regenerate the file with
///
///   UPDATE_CONTRACT=1 flutter test test/contract
///
/// and copy it to `mambo_backend/tests/app_operations.json`.
void main() {
  final file = File('test/contract/operations.json');
  final encoded = '${const JsonEncoder.withIndent('  ').convert(GraphQLOperations.all)}\n';

  test('operations.json matches GraphQLOperations', () {
    if (Platform.environment['UPDATE_CONTRACT'] == '1') {
      file.writeAsStringSync(encoded);
    }
    expect(
      file.existsSync() ? file.readAsStringSync() : '',
      encoded,
      reason:
          'GraphQL operations changed. Run UPDATE_CONTRACT=1 flutter test '
          'test/contract and copy operations.json to the backend.',
    );
  });

  test('every operation is a named document with no inline arguments', () {
    final inlineLiteral = RegExp(r'\(\s*\w+:\s*["\d\[]');
    for (final entry in GraphQLOperations.all.entries) {
      expect(
        entry.value,
        matches(RegExp(r'^(query|mutation) [A-Z]\w*')),
        reason: entry.key,
      );
      expect(inlineLiteral.hasMatch(entry.value), isFalse, reason: entry.key);
    }
  });
}
