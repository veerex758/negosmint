import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
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

  late Future<List<TaskItem>> _tasksFuture;
  String? _busyTaskId;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _loadTasks();
  }

  Future<List<TaskItem>> _loadTasks() async {
    final models = await TaskService.instance.fetchTasks(category: _selected);
    return models.map(TaskItem.fromModel).toList();
  }

  void _reload() {
    setState(() => _tasksFuture = _loadTasks());
  }

  Future<void> _startTask(TaskItem task) async {
    if (task.id == null) return; // demo task with no backend id
    if (!AuthService.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to start a task.')),
      );
      return;
    }

    setState(() => _busyTaskId = task.id);
    try {
      // Starting and completing back-to-back stands in for whatever the
      // real task actually involves (watching a video, filling a survey,
      // etc.) — the reward itself is credited server-side by
      // complete_task(), never by this client directly.
      final submissionId = await TaskService.instance.startTask(task.id!);
      await TaskService.instance.completeTask(submissionId);
      if (!mounted) return;
      await Navigator.of(context).push(
        appRoute(
          TaskCompletionScreen(taskTitle: task.title, reward: task.reward),
        ),
      );
      if (!mounted) return;
      _reload(); // this task now has a submission, so it may drop out of
      // the "available" list depending on how your task list query is set
      // up — refetching keeps the UI honest either way.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busyTaskId = null);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('already completed')) return 'You already completed this task.';
    if (msg.contains('duplicate key')) return 'You already started this task.';
    return 'Something went wrong. Try again.';
  }

  @override
  Widget build(BuildContext context) {
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
                      onTap: () {
                        setState(() => _selected = cat);
                        _reload();
                      },
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
                child: FutureBuilder<List<TaskItem>>(
                  future: _tasksFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.highlight,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(onRetry: _reload);
                    }
                    final tasks = snapshot.data ?? const [];
                    if (tasks.isEmpty) {
                      return const _EmptyState();
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      color: AppColors.highlight,
                      backgroundColor: AppColors.surface,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => TaskCard(
                          task: tasks[i],
                          busy: _busyTaskId == tasks[i].id,
                          onStart: () => _startTask(tasks[i]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No tasks in this category right now — check back soon.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Couldn't load tasks.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.highlight)),
            ),
          ],
        ),
      ),
    );
  }
}
