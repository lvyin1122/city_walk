import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/app/env.dart';

void main() {
  test('free-form recording is disabled without a build define', () {
    expect(Env.enableFreeRecord, isFalse);
  });

  test('the optional free-record flag is not required configuration', () {
    expect(Env.missing, isNot(contains('ENABLE_FREE_RECORD')));
  });
}
