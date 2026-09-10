import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/app_page_route.dart';
import 'task_completion_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _categories = const [
    'All', 'Surveys', 'Apps', 'Social', 'Videos', 'Offers', 'Other'
  ];
  String _selected = 'All';

  final _tasks = const [
    TaskItem(title: 'Complete Survey', category: 'Surveys', reward: 1.50, minutes: 5),
    TaskItem(title: 'Install & Try App', category: 'Apps', reward: 2.25, minutes: 10),
    TaskItem(title: 'Follow & Share', category: 'Social', reward: 0.75, minutes: 3),
    TaskItem(title: 'Watch Short Video', category: 'Videos', reward: 0.40, minutes: 2),
    TaskItem(title: 'Sign Up Offer', category: 'Offers', reward: 4.00, minutes: 15),
  ];

  void _startTask(BuildContext context, TaskItem task) {
    Navigator.of(context).push(
      appRoute(
        TaskCompletionScreen(
          taskTitle: task.title,
          reward: task.reward,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selected == 'All'
        ? _tasks
        : _tasks.where((t) => t.category == _selected).toList();

    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text('Tasks',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final selected = cat == _selected;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: selected ? AppColors.brandGradient : null,
                          color: selected ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: selected
                              ? null
                              : Border.all(color: AppColors.glassBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => TaskCard(
                    task: filtered[i],
                    onStart: () => _startTask(context, filtered[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
