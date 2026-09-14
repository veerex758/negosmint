import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import 'task_completion_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  final TaskItem task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _starting = false;

  static const _genericSteps = [
    'Open the task',
    'Complete the requirements below',
    'Submit for verification',
    'Reward is added to your wallet automatically',
  ];

  Color get _difficultyColor => switch (widget.task.difficulty) {
        'Easy' => AppColors.success,
        'Medium' => AppColors.warning,
        _ => AppColors.danger,
      };

  Future<void> _startTask() async {
    final task = widget.task;
    if (task.id == null) return;
    if (!AuthService.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to start a task.')),
      );
      return;
    }

    setState(() => _starting = true);
    try {
      final submissionId = await TaskService.instance.startTask(task.id!);
      await TaskService.instance.completeTask(submissionId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        appRoute(
          TaskCompletionScreen(taskTitle: task.title, reward: task.reward),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('already completed')) return 'You already completed this task.';
    if (msg.contains('duplicate key')) return 'You already started this task.';
    if (msg.contains('Too many tasks completed')) {
      return "You're completing tasks quickly — take a short break and try again.";
    }
    return 'Something went wrong. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final requirements = (task.requirements ?? '')
        .split(RegExp(r'[,\n]'))
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();

    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Task Details',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    GlassCard(
                      glowColor: AppColors.violet,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.bolt_rounded,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(task.title,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17)),
                                    const SizedBox(height: 2),
                                    Text(task.category,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  label: 'Reward',
                                  value: '\$${task.reward.toStringAsFixed(2)}',
                                  valueColor: AppColors.success,
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  label: 'Est. Time',
                                  value: '${task.minutes} min',
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  label: 'Difficulty',
                                  value: task.difficulty,
                                  valueColor: _difficultyColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('About this task',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      Text(task.description!,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5)),
                    ],
                    if (requirements.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Requirements',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      for (final r in requirements)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 16, color: AppColors.highlight),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(r,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    const Text('Steps',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 10),
                    for (var i = 0; i < _genericSteps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              alignment: Alignment.center,
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      color: AppColors.highlight,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_genericSteps[i],
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Start Task',
                      loading: _starting,
                      onPressed: _startTask,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ],
    );
  }
}
