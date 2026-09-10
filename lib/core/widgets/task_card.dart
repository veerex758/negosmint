import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class TaskItem {
  const TaskItem({
    required this.title,
    required this.category,
    required this.reward,
    required this.minutes,
  });

  final String title;
  final String category;
  final double reward;
  final int minutes;
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, this.onStart});

  final TaskItem task;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
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
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+\$${task.reward.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: TextButton(
                  onPressed: onStart,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.cobalt.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('START',
                      style: TextStyle(
                          color: AppColors.highlight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
