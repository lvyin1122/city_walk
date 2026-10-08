import 'dart:convert';

/// Encodes [value] as a GraphQL string literal, including the quotes.
///
/// Use this for every string placed inline in a GraphQL document. Plain
/// interpolation breaks the request, or lets the text change the query, as
/// soon as the value contains a quote, a backslash or a line break.
///
/// A JSON string is also a valid GraphQL string: both use the same quoting and
/// the same escape sequences.
String gqlString(String value) => jsonEncode(value);
