import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';
import '../../models/task_model.dart';

class TaskItem {
  const TaskItem({
    required this.title,
    required this.category,
    required this.reward,
    required this.minutes,
    this.id,
    this.description,
    this.requirements,
    this.advertiserName,
    this.advertiserRating,
    this.totalSlots,
    this.remainingSlots,
    this.verificationMode = 'manual',
    this.reservationMinutes = 20,
  });

  final String? id;
  final String title;
  final String category;
  final double reward;
  final int minutes;
  final String? description;
  final String? requirements;
  final String? advertiserName;
  final double? advertiserRating;
  final int? totalSlots;
  final int? remainingSlots;
  final String verificationMode;
  final int reservationMinutes;

  bool get isInstantApprove => verificationMode == 'instant';
  String get approvalLabel => isInstantApprove ? 'Instant AI approve' : 'Proof review';

  /// No dedicated difficulty column in the DB — derived from estimated
  /// time, which is a reasonable enough proxy without inventing data.
  String get difficulty {
    if (minutes <= 3) return 'Easy';
    if (minutes <= 10) return 'Medium';
    return 'Hard';
  }

  factory TaskItem.fromModel(TaskModel model) => TaskItem(
        id: model.id,
        title: model.title,
        category: model.category,
        reward: model.reward,
        minutes: model.minutes,
        description: model.description,
        requirements: model.requirements,
        advertiserName: model.advertiserName,
        advertiserRating: model.advertiserRating,
        totalSlots: model.totalSlots,
        remainingSlots: model.remainingSlots,
        verificationMode: model.verificationMode,
        reservationMinutes: model.reservationMinutes,
      );
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, this.onTap, this.busy = false});

  final TaskItem task;
  final VoidCallback? onTap;
  final bool busy;

  Color get _difficultyColor => switch (task.difficulty) {
        'Easy' => AppColors.success,
        'Medium' => AppColors.warning,
        _ => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      onTap: busy ? null : onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.bolt_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text('${task.category} · ${task.minutes} min',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _difficultyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(task.difficulty,
                          style: TextStyle(
                              color: _difficultyColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Text('· ${task.approvalLabel}',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('+\$${task.reward.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(height: 6),
              busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.highlight),
                      ),
                    )
                  : const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
