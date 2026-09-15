/// Stripe publishable key. Same reasoning as SupabaseConfig — safe to ship
/// in a client app (it can only create tokens/PaymentIntents your backend
/// authorizes), but still passed at build time rather than hardcoded, so
/// dev/staging/prod can use different Stripe accounts.
///
///   flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
///
/// The SECRET key never goes here or anywhere in the Flutter app — it
/// lives only in Supabase Edge Function secrets (see
/// supabase/functions/README.md).
class StripeConfig {
  StripeConfig._();

  static const String publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => publishableKey.isNotEmpty;
}
