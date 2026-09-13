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
    final transactionRef = await supabase.rpc('request_withdrawal', params: {
      'p_amount': amount,
      'p_fee': fee,
      'p_method': method,
    });
    return transactionRef as String;
  }

  /// Real earnings for a chart period: buckets completed, positive
  /// (task/referral reward) transactions into `buckets` equal time
  /// slices over the last `days`, and computes % change against the
  /// immediately preceding period of the same length — e.g. this week
  /// vs last week for a 7-day window.
  Future<EarningsSeries> fetchEarningsSeries(
    String userId, {
    required int days,
    required int buckets,
  }) async {
    final now = DateTime.now();
    final periodStart = now.subtract(Duration(days: days));
    final previousStart = now.subtract(Duration(days: days * 2));

    final rows = await supabase
        .from('transactions')
        .select('amount, created_at')
        .eq('user_id', userId)
        .eq('status', 'completed')
        .gt('amount', 0)
        .gte('created_at', previousStart.toIso8601String())
        .order('created_at');

    final bucketTotals = List<double>.filled(buckets, 0);
    final bucketWidth = Duration(
      microseconds: Duration(days: days).inMicroseconds ~/ buckets,
    );

    var currentTotal = 0.0;
    var previousTotal = 0.0;

    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final amount = (map['amount'] as num).toDouble();
      final createdAt = DateTime.parse(map['created_at'] as String);

      if (createdAt.isBefore(periodStart)) {
        previousTotal += amount;
        continue;
      }

      currentTotal += amount;
      final elapsed = createdAt.difference(periodStart);
      var bucketIndex = elapsed.inMicroseconds ~/ bucketWidth.inMicroseconds;
      if (bucketIndex >= buckets) bucketIndex = buckets - 1;
      if (bucketIndex < 0) bucketIndex = 0;
      bucketTotals[bucketIndex] += amount;
    }

    final changePct = previousTotal == 0
        ? (currentTotal > 0 ? 100.0 : 0.0)
        : ((currentTotal - previousTotal) / previousTotal) * 100;

    return EarningsSeries(
      total: currentTotal,
      changePct: changePct,
      points: bucketTotals,
    );
  }
}

class EarningsSeries {
  const EarningsSeries({
    required this.total,
    required this.changePct,
    required this.points,
  });

  final double total;
  final double changePct; // vs the immediately preceding equal-length period
  final List<double> points; // for the chart line

  static const zero = EarningsSeries(total: 0, changePct: 0, points: []);
}
