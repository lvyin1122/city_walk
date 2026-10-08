import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/core/api/graphql_literals.dart';

void main() {
  group('gqlString', () {
    test('wraps plain text in double quotes', () {
      expect(gqlString('abc'), '"abc"');
    });

    test('escapes quotes so the value cannot close the literal', () {
      const hostile = 'coffee") { Id } } mutation { deleteEverything(x: "';
      final literal = gqlString(hostile);

      // Every quote inside the literal is escaped: only the two delimiters
      // are bare quotes.
      final bareQuotes = RegExp(r'(?<!\\)"').allMatches(literal).length;
      expect(bareQuotes, 2);
      expect(jsonDecode(literal), hostile);
    });

    test('escapes backslashes and line breaks', () {
      const value = 'line one\nline two \\ end';
      final literal = gqlString(value);
      expect(literal.contains('\n'), isFalse);
      expect(jsonDecode(literal), value);
    });

    test('keeps non-ASCII text readable', () {
      expect(gqlString('🏙️ 街头文化'), '"🏙️ 街头文化"');
    });
  });
}
