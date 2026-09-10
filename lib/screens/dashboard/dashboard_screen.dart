import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/app_page_route.dart';
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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _tasks = [
    TaskItem(title: 'Complete Survey', category: 'Surveys', reward: 1.50, minutes: 5),
    TaskItem(title: 'Install & Try App', category: 'Apps', reward: 2.25, minutes: 10),
    TaskItem(title: 'Watch Short Video', category: 'Videos', reward: 0.40, minutes: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Hello, Alex!',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context)
                            .push(appRoute(const NotificationsScreen())),
                        icon: const Icon(Icons.notifications_none_rounded,
                            color: AppColors.textPrimary),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.violet,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceElevated,
                    child: Icon(Icons.person, size: 18, color: AppColors.highlight),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const StreakCard(days: 7),
              const SizedBox(height: 16),
              BalanceCard(
                balance: 125.45,
                weeklyChangePct: 12.5,
                onWithdraw: () => Navigator.of(context).push(
                  appRoute(const WithdrawScreen(availableBalance: 125.45)),
                ),
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
                onSelect: (action) {
                  switch (action) {
                    case 'Tasks':
                      Navigator.of(context)
                          .push(appRoute(const TasksScreen()));
                      break;
                    case 'Wallet':
                      Navigator.of(context)
                          .push(appRoute(const WalletScreen()));
                      break;
                    case 'Withdraw':
                      Navigator.of(context).push(
                        appRoute(
                            const WithdrawScreen(availableBalance: 125.45)),
                      );
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
              for (final t in _tasks) ...[
                TaskCard(
                  task: t,
                  onStart: () => Navigator.of(context).push(
                    appRoute(
                      TaskCompletionScreen(
                        taskTitle: t.title,
                        reward: t.reward,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
