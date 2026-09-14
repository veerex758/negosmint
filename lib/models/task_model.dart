class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.category,
    required this.reward,
    required this.minutes,
    this.description,
    this.requirements,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String category;
  final double reward;
  final int minutes;
  final String? description;
  final String? requirements;
  final bool isActive;

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      reward: (map['reward'] as num).toDouble(),
      minutes: map['minutes'] as int,
      description: map['description'] as String?,
      requirements: map['requirements'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class TaskSubmission {
  const TaskSubmission({
    required this.id,
    required this.taskId,
    required this.status,
  });

  final String id;
  final String taskId;
  final String status; // in_progress, submitted, under_review, completed, rejected, expired

  factory TaskSubmission.fromMap(Map<String, dynamic> map) {
    return TaskSubmission(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      status: map['status'] as String,
    );
  }
}
