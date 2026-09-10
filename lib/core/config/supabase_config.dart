/// Supabase configuration for NegosMint.
///
/// Values are supplied at build/run time using --dart-define.
///
/// Example:
/// flutter run --dart-define=SUPABASE_URL=your_url \
/// --dart-define=SUPABASE_PUBLISHABLE_KEY=your_publishable_key
class SupabaseConfig {
  SupabaseConfig._();

  /// Your Supabase project URL.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Your Supabase publishable key.
  ///
  /// This replaces the deprecated `anonKey` parameter.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Returns true only when both required Supabase
  /// configuration values have been provided.
  static bool get isConfigured {
    return url.isNotEmpty && publishableKey.isNotEmpty;
  }
}