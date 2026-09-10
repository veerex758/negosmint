/// Supabase project credentials.
///
/// The anon key is safe to ship in a client app by design (it only grants
/// what your Row Level Security policies allow) — but it still shouldn't
/// be hardcoded into source control, since that makes it awkward to use
/// different projects for dev/staging/prod. Pass both values at build/run
/// time instead:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// For CI (GitHub Actions), add them as repo secrets and pass the same
/// flags in your build-apk.yml step, e.g.:
///
///   flutter build apk --release \
///     --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
///     --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
