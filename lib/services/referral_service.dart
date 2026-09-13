import 'supabase_client.dart';
import '../models/referral_stats.dart';

class ReferralService {
  ReferralService._();
  static final instance = ReferralService._();

  Future<ReferralStats> fetchStats(String userId) async {
    final rows = await supabase
        .from('referrals')
        .select('reward_earned')
        .eq('referrer_id', userId);
    final list = rows as List;
    final total = list.fold<double>(
      0,
      (sum, r) => sum + ((r as Map<String, dynamic>)['reward_earned'] as num).toDouble(),
    );
    return ReferralStats(totalReferrals: list.length, totalEarnings: total);
  }
}
