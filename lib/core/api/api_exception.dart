/// Failure of a backend call.
///
/// [toString] returns [userMessage], a short Chinese sentence that is safe to
/// show in the UI, so existing `'操作失败：$e'` messages stay readable.
/// [details] carries the technical cause for logs.
sealed class ApiException implements Exception {
  const ApiException(this.details);

  /// Technical description for logs. Never show this to the user.
  final String details;

  /// What the user should read.
  String get userMessage;

  @override
  String toString() => userMessage;
}

/// The request never reached the server.
final class ApiNetworkException extends ApiException {
  const ApiNetworkException(super.details);

  @override
  String get userMessage => '网络连接失败，请检查网络后重试';
}

/// The server did not answer in time.
final class ApiTimeoutException extends ApiException {
  const ApiTimeoutException(super.details);

  @override
  String get userMessage => '请求超时，请稍后重试';
}

/// The server answered with a non-success HTTP status.
final class ApiHttpException extends ApiException {
  const ApiHttpException(this.statusCode, super.details);

  final int statusCode;

  @override
  String get userMessage =>
      statusCode == 401 || statusCode == 403
          ? '登录已失效，请重新登录'
          : '服务暂时不可用，请稍后重试';
}

/// The server answered 200 but reported GraphQL errors.
final class ApiGraphQLException extends ApiException {
  ApiGraphQLException(this.messages) : super(messages.join('; '));

  final List<String> messages;

  @override
  String get userMessage => '服务处理请求时出错，请稍后重试';
}

/// The response was not the JSON document the client expected.
final class ApiResponseFormatException extends ApiException {
  const ApiResponseFormatException(super.details);

  @override
  String get userMessage => '服务返回了无法识别的数据，请稍后重试';
}
