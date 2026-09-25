class TaskModel {
  const TaskModel({
    required this.id, required this.title, required this.category,
    required this.reward, required this.minutes, this.description,
    this.requirements, this.isActive = true, this.advertiserName,
    this.advertiserRating, this.totalSlots, this.remainingSlots,
    this.verificationMode = 'manual', this.reservationMinutes = 20,
  });

  final String id;
  final String title;
  final String category;
  final double reward;
  final int minutes;
  final String? description;
  final String? requirements;
  final bool isActive;
  final String? advertiserName;
  final double? advertiserRating;
  final int? totalSlots;
  final int? remainingSlots;
  final String verificationMode;
  final int reservationMinutes;

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel(
    id: map['id'] as String,
    title: map['title'] as String,
    category: map['category'] as String,
    reward: (map['reward'] as num).toDouble(),
    minutes: map['minutes'] as int,
    description: map['description'] as String?,
    requirements: map['requirements'] as String?,
    isActive: map['is_active'] as bool? ?? true,
    advertiserName: map['advertiser_name'] as String?,
    advertiserRating: (map['advertiser_rating'] as num?)?.toDouble(),
    totalSlots: map['total_slots'] as int?,
    remainingSlots: map['remaining_slots'] as int?,
    verificationMode: map['verification_mode'] as String? ?? 'manual',
    reservationMinutes: map['reservation_minutes'] as int? ?? 20,
  );
}

class TaskSubmission {
  const TaskSubmission({required this.id, required this.taskId, required this.status, this.reservedUntil});
  final String id;
  final String taskId;
  final String status;
  final DateTime? reservedUntil;
  factory TaskSubmission.fromMap(Map<String, dynamic> map) => TaskSubmission(
    id: map['id'] as String, taskId: map['task_id'] as String,
    status: map['status'] as String,
    reservedUntil: map['reserved_until'] == null ? null : DateTime.parse(map['reserved_until'] as String),
  );
}
