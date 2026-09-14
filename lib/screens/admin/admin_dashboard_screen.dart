import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/admin_service.dart';
import '../../models/admin_analytics.dart';
import '../../models/admin_withdrawal.dart';
import '../../models/admin_user_row.dart';
import '../../models/task_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;
  static const _tabs = ['Overview', 'Withdrawals', 'Tasks', 'Users'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final selected = i == _tab;
                    return GestureDetector(
                      onTap: () => setState(() => _tab = i),
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
                          _tabs[i],
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
                child: IndexedStack(
                  index: _tab,
                  children: const [
                    _OverviewTab(),
                    _WithdrawalsTab(),
                    _TasksTab(),
                    _UsersTab(),
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

// ---------------------------------------------------------------------------
// OVERVIEW
// ---------------------------------------------------------------------------
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<AdminAnalytics> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.instance.fetchAnalytics();
  }

  void _reload() =>
      setState(() => _future = AdminService.instance.fetchAnalytics());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminAnalytics>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.highlight),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text("Couldn't load analytics — Retry",
                  style: TextStyle(color: AppColors.highlight)),
            ),
          );
        }
        final a = snapshot.data!;
        final cards = [
          ('Total Users', '${a.totalUsers}'),
          ('Active Users (30d)', '${a.activeUsers}'),
          ('Tasks Completed', '${a.tasksCompleted}'),
          ('Total Rewards', '\$${a.totalRewards.toStringAsFixed(2)}'),
          ('Total Withdrawals', '\$${a.totalWithdrawals.toStringAsFixed(2)}'),
          ('Revenue', '\$${a.revenue.toStringAsFixed(2)}'),
        ];
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          color: AppColors.highlight,
          backgroundColor: AppColors.surface,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) => GlassCard(
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cards[i].$2,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(cards[i].$1,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// WITHDRAWALS
// ---------------------------------------------------------------------------
class _WithdrawalsTab extends StatefulWidget {
  const _WithdrawalsTab();

  @override
  State<_WithdrawalsTab> createState() => _WithdrawalsTabState();
}

class _WithdrawalsTabState extends State<_WithdrawalsTab> {
  late Future<List<AdminWithdrawal>> _future;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _future = AdminService.instance.fetchWithdrawals(status: 'pending');
  }

  void _reload() => setState(() {
        _future = AdminService.instance.fetchWithdrawals(status: 'pending');
      });

  Future<void> _act(String id, bool approve) async {
    setState(() => _busyId = id);
    try {
      if (approve) {
        await AdminService.instance.approveWithdrawal(id);
      } else {
        await AdminService.instance.rejectWithdrawal(id);
      }
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminWithdrawal>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.highlight),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text("Couldn't load withdrawals — Retry",
                  style: TextStyle(color: AppColors.highlight)),
            ),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(
            child: Text('No pending withdrawals.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          color: AppColors.highlight,
          backgroundColor: AppColors.surface,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final w = items[i];
              final busy = _busyId == w.id;
              return GlassCard(
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('@${w.username}',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                        Text('\$${w.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${w.method} · ${w.transactionRef}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Reject',
                            outlined: true,
                            loading: busy,
                            onPressed: () => _act(w.id, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Approve',
                            loading: busy,
                            onPressed: () => _act(w.id, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// TASKS
// ---------------------------------------------------------------------------
class _TasksTab extends StatefulWidget {
  const _TasksTab();

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  late Future<List<TaskModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.instance.fetchAllTasks();
  }

  void _reload() =>
      setState(() => _future = AdminService.instance.fetchAllTasks());

  Future<void> _toggleActive(TaskModel task) async {
    await AdminService.instance.setTaskActive(task.id, !task.isActive);
    _reload();
  }

  Future<void> _showCreateSheet() async {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final rewardCtrl = TextEditingController();
    final minutesCtrl = TextEditingController();

    final created = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Task',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                  hintText:
                      'Category (Surveys, Apps, Social, Videos, Offers)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rewardCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(hintText: 'Reward (\$)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: minutesCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(hintText: 'Minutes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Create Task',
              onPressed: () async {
                final reward = double.tryParse(rewardCtrl.text);
                final minutes = int.tryParse(minutesCtrl.text);
                if (titleCtrl.text.trim().isEmpty ||
                    categoryCtrl.text.trim().isEmpty ||
                    reward == null ||
                    minutes == null) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('Fill in every field.')),
                  );
                  return;
                }
                try {
                  await AdminService.instance.createTask(
                    title: titleCtrl.text.trim(),
                    category: categoryCtrl.text.trim(),
                    reward: reward,
                    minutes: minutes,
                  );
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop(true);
                  }
                } catch (_) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('Could not create task.')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );

    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.highlight),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text("Couldn't load tasks — Retry",
                  style: TextStyle(color: AppColors.highlight)),
            ),
          );
        }
        final tasks = snapshot.data ?? const [];
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async => _reload(),
              color: AppColors.highlight,
              backgroundColor: AppColors.surface,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final t = tasks[i];
                  return GlassCard(
                    borderRadius: 18,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text(
                                  '${t.category} · \$${t.reward.toStringAsFixed(2)} · ${t.minutes}min',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch(
                          value: t.isActive,
                          activeThumbColor: AppColors.cobalt,
                          onChanged: (_) => _toggleActive(t),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: 0,
              bottom: 8,
              child: FloatingActionButton(
                onPressed: _showCreateSheet,
                backgroundColor: AppColors.cobalt,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// USERS
// ---------------------------------------------------------------------------
class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<AdminUserRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.instance.fetchUsers();
  }

  void _reload() =>
      setState(() => _future = AdminService.instance.fetchUsers());

  Future<void> _toggleSuspend(AdminUserRow user) async {
    await AdminService.instance.setUserSuspended(user.id, !user.isSuspended);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminUserRow>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.highlight),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text("Couldn't load users — Retry",
                  style: TextStyle(color: AppColors.highlight)),
            ),
          );
        }
        final users = snapshot.data ?? const [];
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          color: AppColors.highlight,
          backgroundColor: AppColors.surface,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final u = users[i];
              return GlassCard(
                borderRadius: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(u.fullName,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              if (u.isAdmin) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.shield,
                                    size: 14, color: AppColors.highlight),
                              ],
                            ],
                          ),
                          Text('@${u.username}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!u.isAdmin)
                      TextButton(
                        onPressed: () => _toggleSuspend(u),
                        child: Text(
                          u.isSuspended ? 'Unsuspend' : 'Suspend',
                          style: TextStyle(
                            color: u.isSuspended
                                ? AppColors.success
                                : AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
