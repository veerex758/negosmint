class AdminAnalytics {
  const AdminAnalytics({
    required this.totalUsers,
    required this.activeUsers,
    required this.tasksCompleted,
    required this.totalRewards,
    required this.totalWithdrawals,
    required this.revenue,
  });

  final int totalUsers;
  final int activeUsers;
  final int tasksCompleted;
  final double totalRewards;
  final double totalWithdrawals;
  final double revenue;

  static const zero = AdminAnalytics(
    totalUsers: 0,
    activeUsers: 0,
    tasksCompleted: 0,
    totalRewards: 0,
    totalWithdrawals: 0,
    revenue: 0,
  );

  factory AdminAnalytics.fromMap(Map<String, dynamic> map) {
    return AdminAnalytics(
      totalUsers: (map['total_users'] as num).toInt(),
      activeUsers: (map['active_users'] as num).toInt(),
      tasksCompleted: (map['tasks_completed'] as num).toInt(),
      totalRewards: (map['total_rewards'] as num).toDouble(),
      totalWithdrawals: (map['total_withdrawals'] as num).toDouble(),
      revenue: (map['revenue'] as num).toDouble(),
    );
  }
}
