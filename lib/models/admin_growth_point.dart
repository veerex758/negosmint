class AdminGrowthPoint {
  const AdminGrowthPoint({
    required this.day,
    required this.newUsers,
    required this.tasksCompleted,
    required this.withdrawalVolume,
  });

  final DateTime day;
  final int newUsers;
  final int tasksCompleted;
  final double withdrawalVolume;

  factory AdminGrowthPoint.fromMap(Map<String, dynamic> map) {
    return AdminGrowthPoint(
      day: DateTime.parse(map['day'] as String),
      newUsers: (map['new_users'] as num).toInt(),
      tasksCompleted: (map['tasks_completed'] as num).toInt(),
      withdrawalVolume: (map['withdrawal_volume'] as num).toDouble(),
    );
  }
}
