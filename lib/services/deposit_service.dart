import 'supabase_client.dart';

/// Wraps the create-payment-intent and confirm-deposit Edge Functions.
/// Deliberately thin — all the actual trust decisions (is this really a
/// successful payment, whose deposit is this) happen server-side; this
/// class just shuttles requests/responses.
class DepositService {
  DepositService._();
  static final instance = DepositService._();

  /// Starts a deposit: creates a Stripe Customer for this user if they
  /// don't have one yet, a PaymentIntent for [amount], and returns
  /// everything flutter_stripe's PaymentSheet needs to collect payment.
  Future<
      ({
        String clientSecret,
        String paymentIntentId,
        String ephemeralKey,
        String customerId
      })> createPaymentIntent(double amount) async {
    final response = await supabase.functions.invoke(
      'create-payment-intent',
      body: {'amount': amount},
    );
    if (response.status != 200) {
      throw Exception(_extractError(response.data) ?? 'Could not start deposit');
    }
    final data = response.data as Map<String, dynamic>;
    final clientSecret = data['paymentIntent'] as String;
    return (
      clientSecret: clientSecret,
      // A PaymentIntent client secret is "pi_XXXX_secret_YYYY" — the
      // part before "_secret_" is the PaymentIntent's own id, which
      // confirm-deposit needs to look Stripe's record back up.
      paymentIntentId: clientSecret.split('_secret_').first,
      ephemeralKey: data['ephemeralKey'] as String,
      customerId: data['customer'] as String,
    );
  }

  /// Called right after the PaymentSheet reports success. The server
  /// re-checks with Stripe directly before crediting anything — see the
  /// comments in supabase/functions/confirm-deposit/index.ts.
  Future<bool> confirmDeposit(String paymentIntentId) async {
    final response = await supabase.functions.invoke(
      'confirm-deposit',
      body: {'paymentIntentId': paymentIntentId},
    );
    if (response.status != 200) {
      throw Exception(_extractError(response.data) ?? 'Could not confirm deposit');
    }
    final data = response.data as Map<String, dynamic>;
    return data['success'] as bool? ?? false;
  }

  String? _extractError(Object? data) {
    if (data is Map<String, dynamic>) return data['error'] as String?;
    return null;
  }
}
