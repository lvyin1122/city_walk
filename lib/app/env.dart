/// Build-time configuration.
///
/// Values are injected when the app is built or run:
///
/// ```sh
/// flutter run --dart-define-from-file=.env
/// ```
///
/// Everything read here ends up inside the installed app and can be extracted
/// from it. Only put values here that are safe to publish: the Supabase URL
/// and publishable key (protected by row level security) and the backend URL. Never add a secret such as a service role key
/// or a third-party API key.
abstract final class Env {
  /// The free-form record flow; off for 1.0.
  static const enableFreeRecord = bool.fromEnvironment('ENABLE_FREE_RECORD');

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const graphqlEndpoint = String.fromEnvironment('GRAPHQL_ENDPOINT');
  /// Whether backend requests carry the user's access token in an
  /// `Authorization` header. On by default and required by the backend,
  /// which verifies the token. Only turn it off against a local backend
  /// running with `AUTH_DISABLED=1`.
  static const sendAuthHeader = bool.fromEnvironment(
    'API_SEND_AUTH_HEADER',
    defaultValue: true,
  );

  /// Names of the required values that were not provided at build time.
  static List<String> get missing => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    if (graphqlEndpoint.isEmpty) 'GRAPHQL_ENDPOINT',
  ];
}
