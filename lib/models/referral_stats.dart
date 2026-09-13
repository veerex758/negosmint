class ReferralStats {
  const ReferralStats({
    required this.totalReferrals,
    required this.totalEarnings,
  });

  final int totalReferrals;
  final double totalEarnings;

  static const zero = ReferralStats(totalReferrals: 0, totalEarnings: 0);
}
