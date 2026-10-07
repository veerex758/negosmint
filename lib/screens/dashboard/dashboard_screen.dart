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
import '../tasks/task_detail_screen.dart';
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
  int level,
});

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<_DashboardData>? _dataFuture;

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
        AuthService.instance.fetchLevel(userId),
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
        level: (results[5] as ({int xp, int level})).level,
      );
    }();
  }

  void _reload() => setState(() => _dataFuture = _load());

  Future<void> _openTask(TaskItem task) async {
    await Navigator.of(context).push(appRoute(TaskDetailScreen(task: task)));
    _reload();
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
                              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)), child: Text('LEVEL ${data.level}', style: const TextStyle(color: AppColors.highlight, fontSize: 10, fontWeight: FontWeight.w800))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello, $name 👋',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Text(
                                      'Ready to earn today?',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
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
                            pendingBalance: data.balance.pending,
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
                          const Text('Quick access',
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
                          const Text('Recommended for you',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          if (data.tasks.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '⚡ ${data.tasks.length} task${data.tasks.length == 1 ? '' : 's'} · Up to \$${data.tasks.map((t) => t.reward).fold(0.0, (a, b) => a + b).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
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
                                onTap: () => _openTask(t),
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
