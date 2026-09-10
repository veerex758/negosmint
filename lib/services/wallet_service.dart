import 'supabase_client.dart';
import '../models/wallet_transaction.dart';

/// Reads from `wallet_balances` (a view over the transactions ledger) and
/// `transactions` directly. There is deliberately no `updateBalance()` or
/// similar here — the balance is derived, never written to directly. See
/// supabase/schema.sql for why.
class WalletService {
  WalletService._();
  static final instance = WalletService._();

  Future<WalletBalance> fetchBalance(String userId) async {
    final row = await supabase
        .from('wallet_balances')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? WalletBalance.zero : WalletBalance.fromMap(row);
  }

  /// Live-updates whenever a new transaction lands for this user (a task
  /// reward, a withdrawal, etc.) — the UI doesn't need to poll or manually
  /// refresh after completing a task.
  Stream<WalletBalance> watchBalance(String userId) {
    return supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((_) => null) // any change to this user's transactions...
        .asyncMap((_) => fetchBalance(userId)); // ...re-derives the balance
  }

  Future<List<WalletTransaction>> fetchTransactions(String userId,
      {int limit = 30}) async {
    final rows = await supabase
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => WalletTransaction.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Calls request_withdrawal(), the SECURITY DEFINER function that
  /// re-checks the available balance server-side before debiting the
  /// ledger — never trust a balance number the client computed itself.
  Future<String> requestWithdrawal({
    required double amount,
    required double fee,
    required String method,
  }) async {
    final withdrawalId = await supabase.rpc('request_withdrawal', params: {
      'p_amount': amount,
      'p_fee': fee,
      'p_method': method,
    });
    return withdrawalId as String;
  }
}
