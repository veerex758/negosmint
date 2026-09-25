import 'supabase_client.dart';
import 'wallet_service.dart';

/// Client-side transport for the JWT-protected create-payment-intent function.
///
/// This service never confirms or credits a deposit. Stripe's webhook is the
/// only authority that changes a deposit status and writes to the wallet
/// ledger.
class DepositService {
  DepositService._();
  static final instance = DepositService._();

  /// Creates a PaymentIntent for [amount] in USD.
  ///
  /// The deployed Edge Function expects a dollar amount as a JSON number; it
  /// performs the cents conversion and enforces its own limits server-side.
  Future<({String clientSecret, String? ephemeralKey, String? customerId})>
      createPaymentIntent(double amount) async {
    if (supabase.auth.currentSession == null ||
        supabase.auth.currentUser == null) {
      throw const DepositException('Please sign in before making a deposit.');
    }

    final response = await supabase.functions.invoke(
      'create-payment-intent',
      body: {'amount': amount},
    );
    if (response.status != 200) {
      throw DepositException(
        _extractError(response.data) ?? 'Could not start the deposit.',
      );
    }
    if (response.data is! Map) {
      throw const DepositException(
        'The payment service returned an invalid response.',
      );
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    // `client_secret` is the deployed function contract. `paymentIntent` is
    // accepted temporarily for compatibility with earlier app deployments.
    final clientSecret =
        data['client_secret'] ?? data['clientSecret'] ?? data['paymentIntent'];
    if (clientSecret is! String || clientSecret.isEmpty) {
      throw const DepositException(
        'The payment service did not return a client secret.',
      );
    }

    return (
      clientSecret: clientSecret,
      ephemeralKey: data['ephemeralKey'] as String?,
      customerId: data['customer'] as String?,
    );
  }

  /// Re-fetches the server-owned wallet ledger and the pending deposit row
  /// after Stripe confirms payment in the SDK. The webhook may still be
  /// processing, so callers must not infer that the deposit was credited from
  /// this refresh.
  Future<void> refreshAuthoritativeData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await Future.wait([
      WalletService.instance.fetchBalance(user.id),
      WalletService.instance.fetchTransactions(user.id),
      supabase
          .from('deposits')
          .select('id, status, amount, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(30),
    ]);
  }

  String? _extractError(Object? data) {
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return null;
  }
}

class DepositException implements Exception {
  const DepositException(this.message);

  final String message;

  @override
  String toString() => message;
}
