import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/primary_button.dart';
import 'withdraw_screen.dart';
import '../../core/widgets/app_page_route.dart';

class _Txn {
  const _Txn(this.title, this.subtitle, this.amount, this.kind);
  final String title;
  final String subtitle;
  final double amount;
  final String kind; // earning, referral, withdrawal, pending
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const _txns = [
    _Txn('Task completed', 'Complete Survey', 5.00, 'earning'),
    _Txn('Referral reward', 'Invited @jordan', 2.50, 'referral'),
    _Txn('Withdrawal', 'Bank transfer', -10.00, 'withdrawal'),
    _Txn('Task completed', 'Watch Short Video', 0.40, 'earning'),
  ];

  Color _kindColor(String kind) {
    switch (kind) {
      case 'earning':
        return AppColors.success;
      case 'referral':
        return AppColors.highlight;
      case 'withdrawal':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'earning':
        return Icons.add_circle_outline;
      case 'referral':
        return Icons.groups_outlined;
      case 'withdrawal':
        return Icons.north_east_rounded;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const Text('Wallet',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              GlassCard(
                glowColor: AppColors.violet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Balance',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    const AnimatedCounter(
                      value: 125.45,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(
                            child: _Breakdown(label: 'Available', value: 110.20)),
                        Expanded(child: _Breakdown(label: 'Pending', value: 15.25)),
                        Expanded(
                            child: _Breakdown(label: 'Lifetime', value: 482.10)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                              label: 'Deposit', outlined: true, onPressed: () {}),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Withdraw',
                            onPressed: () => Navigator.of(context).push(
                              appRoute(
                                const WithdrawScreen(availableBalance: 110.20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Transaction History',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 12),
              for (final t in _txns) ...[
                GlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _kindColor(t.kind).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_kindIcon(t.kind),
                            size: 18, color: _kindColor(t.kind)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(t.subtitle,
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(
                        '${t.amount >= 0 ? '+' : '-'}\$${t.amount.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: t.amount >= 0
                              ? AppColors.success
                              : AppColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text('\$${value.toStringAsFixed(2)}',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ],
    );
  }
}
