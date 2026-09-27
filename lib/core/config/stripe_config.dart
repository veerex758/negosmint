/// Stripe publishable key. Same reasoning as SupabaseConfig — safe to ship
/// in a client app (it can only create tokens/PaymentIntents your backend
/// authorizes). This default is the NegosMint Stripe **test-mode** key. A
/// `--dart-define` can override it for a different test, staging, or live
/// Stripe account without changing source code.
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
    defaultValue:
        'pk_test_51UJWJ2GzbkKcFOab6kk0ezRJVVt47gjNJUoJATxD4Zh5CINdWeEPWRIvgHo3fTqPCcfifmjUFH6MpvWKFz4LXEKl000mE98xzP',
  );

  static bool get isConfigured => publishableKey.isNotEmpty;
}
