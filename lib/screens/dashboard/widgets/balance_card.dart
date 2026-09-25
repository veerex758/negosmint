import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/animated_coin.dart';
import '../../../core/widgets/animated_counter.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.pendingBalance,
    required this.weeklyChangePct,
    this.onWithdraw,
    this.onWallet,
  });

  final double balance;
  final double pendingBalance;
  final double weeklyChangePct;
  final VoidCallback? onWithdraw;
  final VoidCallback? onWallet;

  @override
  Widget build(BuildContext context) {
    final up = weeklyChangePct >= 0;
    return GlassCard(
      glowColor: AppColors.violet,
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available balance',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    AnimatedCounter(
                      value: balance,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pending ledger · ₦${pendingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          up ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14,
                          color: up ? AppColors.success : AppColors.danger,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${weeklyChangePct.abs().toStringAsFixed(1)}% this week',
                          style: TextStyle(
                            color: up ? AppColors.success : AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const AnimatedCoin(size: 64),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ActionChip(
                  label: 'Withdraw',
                  icon: Icons.north_east_rounded,
                  filled: true,
                  onTap: onWithdraw,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionChip(
                  label: 'Earn More',
                  icon: Icons.account_balance_wallet_outlined,
                  filled: false,
                  onTap: onWallet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.filled,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: filled ? AppColors.brandGradient : null,
          border: filled ? null : Border.all(color: AppColors.glassBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
