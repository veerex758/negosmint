import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../services/task_service.dart';
import '../../models/app_profile.dart';
import '../../models/wallet_transaction.dart';
import '../notifications/notifications_screen.dart';
import '../tasks/task_completion_screen.dart';
import '../tasks/tasks_screen.dart';
import '../wallet/wallet_screen.dart';
import '../wallet/withdraw_screen.dart';
import '../referral/referral_screen.dart';
import 'widgets/balance_card.dart';
import 'widgets/streak_card.dart';
import 'widgets/quick_actions.dart';
import 'widgets/earnings_chart.dart';

typedef _DashboardData = ({
  AppProfile? profile,
  WalletBalance balance,
  int streak,
  List<TaskItem> tasks,
  double weeklyChangePct,
});

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<_DashboardData>? _dataFuture;
  String? _busyTaskId;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_DashboardData>? _load() {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return null;
    return () async {
      final results = await Future.wait([
        AuthService.instance.fetchCurrentProfile(),
        WalletService.instance.fetchBalance(userId),
        AuthService.instance.fetchStreak(userId),
        TaskService.instance.fetchTasks(),
        WalletService.instance.fetchEarningsSeries(userId, days: 7, buckets: 1),
      ]);
      final tasks = (results[3] as List).cast<dynamic>();
      final weekSeries = results[4] as EarningsSeries;
      return (
        profile: results[0] as AppProfile?,
        balance: results[1] as WalletBalance,
        streak: results[2] as int,
        tasks: [
          for (final t in tasks.take(3)) TaskItem.fromModel(t),
        ],
        weeklyChangePct: weekSeries.changePct,
      );
    }();
  }

  void _reload() => setState(() => _dataFuture = _load());

  Future<void> _startTask(TaskItem task) async {
    if (task.id == null) return;
    setState(() => _busyTaskId = task.id);
    try {
      final submissionId = await TaskService.instance.startTask(task.id!);
      await TaskService.instance.completeTask(submissionId);
      if (!mounted) return;
      await Navigator.of(context).push(
        appRoute(
          TaskCompletionScreen(taskTitle: task.title, reward: task.reward),
        ),
      );
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      final errText = e.toString();
      final msg = errText.contains('already completed')
          ? 'You already completed this task.'
          : errText.contains('Too many tasks completed')
              ? "You're completing tasks quickly — take a short break and try again."
              : 'Something went wrong. Try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busyTaskId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: _dataFuture == null
              ? const _SignedOutState()
              : FutureBuilder<_DashboardData>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.highlight),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton(
                          onPressed: _reload,
                          child: const Text("Couldn't load your data — Retry",
                              style: TextStyle(color: AppColors.highlight)),
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    final name = data.profile?.fullName.split(' ').first ??
                        data.profile?.username ??
                        'there';

                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      color: AppColors.highlight,
                      backgroundColor: AppColors.surface,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.menu_rounded,
                                  color: AppColors.textPrimary),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Hello, $name!',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).push(
                                    appRoute(const NotificationsScreen())),
                                icon: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(width: 8),
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.surfaceElevated,
                                child: Icon(Icons.person,
                                    size: 18, color: AppColors.highlight),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          StreakCard(days: data.streak),
                          const SizedBox(height: 16),
                          BalanceCard(
                            balance: data.balance.available,
                            weeklyChangePct: data.weeklyChangePct,
                            onWithdraw: () async {
                              await Navigator.of(context).push(
                                appRoute(
                                  WithdrawScreen(
                                    availableBalance: data.balance.available,
                                  ),
                                ),
                              );
                              _reload();
                            },
                            onWallet: () => Navigator.of(context)
                                .push(appRoute(const WalletScreen())),
                          ),
                          const SizedBox(height: 20),
                          const Text('Quick Actions',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 12),
                          QuickActions(
                            onSelect: (action) async {
                              switch (action) {
                                case 'Tasks':
                                  await Navigator.of(context)
                                      .push(appRoute(const TasksScreen()));
                                  _reload();
                                  break;
                                case 'Wallet':
                                  Navigator.of(context)
                                      .push(appRoute(const WalletScreen()));
                                  break;
                                case 'Withdraw':
                                  await Navigator.of(context).push(
                                    appRoute(
                                      WithdrawScreen(
                                        availableBalance:
                                            data.balance.available,
                                      ),
                                    ),
                                  );
                                  _reload();
                                  break;
                                case 'Refer':
                                  Navigator.of(context)
                                      .push(appRoute(const ReferralScreen()));
                                  break;
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          const EarningsChart(),
                          const SizedBox(height: 20),
                          const Text('Available Tasks',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 12),
                          if (data.tasks.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No tasks available right now.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            )
                          else
                            for (final t in data.tasks) ...[
                              TaskCard(
                                task: t,
                                busy: _busyTaskId == t.id,
                                onStart: () => _startTask(t),
                              ),
                              const SizedBox(height: 12),
                            ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Sign in to view your dashboard.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}
