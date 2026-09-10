import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../dashboard/dashboard_screen.dart';
import '../tasks/tasks_screen.dart';
import '../wallet/wallet_screen.dart';
import '../referral/referral_screen.dart';
import '../profile/profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    TasksScreen(),
    WalletScreen(),
    ReferralScreen(),
    ProfileScreen(),
  ];

  final _icons = const [
    Icons.home_rounded,
    Icons.task_alt_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.groups_rounded,
    Icons.person_rounded,
  ];

  final _labels = const ['Home', 'Tasks', 'Wallet', 'Refer', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: List.generate(_icons.length, (i) {
                    final selected = i == _index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _index = i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: selected ? AppColors.brandGradient : null,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: AppColors.cobalt.withOpacity(0.35),
                                      blurRadius: 16,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _icons[i],
                                size: 20,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              if (selected) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _labels[i],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
