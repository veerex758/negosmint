class AdminAnalytics {
  const AdminAnalytics({
    required this.totalUsers,
    required this.activeUsers,
    required this.tasksCompleted,
    required this.totalRewards,
    required this.totalWithdrawals,
    required this.revenue,
    required this.newUsersToday,
    required this.tasksCompletedToday,
    required this.pendingWithdrawals,
    required this.revenueToday,
  });

  final int totalUsers;
  final int activeUsers;
  final int tasksCompleted;
  final double totalRewards;
  final double totalWithdrawals;
  final double revenue;
  final int newUsersToday;
  final int tasksCompletedToday;
  final int pendingWithdrawals;
  final double revenueToday;

  static const zero = AdminAnalytics(
    totalUsers: 0,
    activeUsers: 0,
    tasksCompleted: 0,
    totalRewards: 0,
    totalWithdrawals: 0,
    revenue: 0,
    newUsersToday: 0,
    tasksCompletedToday: 0,
    pendingWithdrawals: 0,
    revenueToday: 0,
  );

  factory AdminAnalytics.fromMap(Map<String, dynamic> map) {
    return AdminAnalytics(
      totalUsers: (map['total_users'] as num).toInt(),
      activeUsers: (map['active_users'] as num).toInt(),
      tasksCompleted: (map['tasks_completed'] as num).toInt(),
      totalRewards: (map['total_rewards'] as num).toDouble(),
      totalWithdrawals: (map['total_withdrawals'] as num).toDouble(),
      revenue: (map['revenue'] as num).toDouble(),
      newUsersToday: (map['new_users_today'] as num?)?.toInt() ?? 0,
      tasksCompletedToday:
          (map['tasks_completed_today'] as num?)?.toInt() ?? 0,
      pendingWithdrawals: (map['pending_withdrawals'] as num?)?.toInt() ?? 0,
      revenueToday: (map['revenue_today'] as num?)?.toDouble() ?? 0,
    );
  }
}
