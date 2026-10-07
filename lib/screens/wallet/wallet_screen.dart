import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../models/wallet_transaction.dart';
import 'withdraw_screen.dart';
import 'deposit_screen.dart';

typedef _WalletData = ({WalletBalance balance, List<WalletTransaction> txns});

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Future<_WalletData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  String? get _userId => AuthService.instance.currentUser?.id;

  Future<_WalletData>? _load() {
    final userId = _userId;
    if (userId == null) return null;
    return () async {
      final results = await Future.wait([
        WalletService.instance.fetchBalance(userId),
        WalletService.instance.fetchTransactions(userId),
      ]);
      return (
        balance: results[0] as WalletBalance,
        txns: results[1] as List<WalletTransaction>,
      );
    }();
  }

  void _reload() => setState(() => _dataFuture = _load());

  String _title(WalletTransaction t) {
    switch (t.type) {
      case 'task_reward':
        return 'Task reward';
      case 'referral_reward':
        return 'Referral reward';
      case 'withdrawal':
        return 'Withdrawal';
      case 'deposit':
        return 'Deposit';
      case 'adjustment':
        return 'Refund';
      default:
        return 'Adjustment';
    }
  }

  String _kind(WalletTransaction t) {
    if (t.status == 'pending') return 'pending';
    if (t.type == 'withdrawal') return 'withdrawal';
    if (t.type == 'referral_reward') return 'referral';
    if (t.type == 'adjustment') return 'refund';
    return 'earning';
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case 'earning':
        return AppColors.success;
      case 'referral':
        return AppColors.highlight;
      case 'withdrawal':
        return AppColors.danger;
      case 'refund':
        return AppColors.violet;
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
      case 'refund':
        return Icons.replay_rounded;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: _dataFuture == null
              ? const _SignedOutState()
              : FutureBuilder<_WalletData>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.highlight),
                      );
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(onRetry: _reload);
                    }
                    final data = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      color: AppColors.highlight,
                      backgroundColor: AppColors.surface,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Wallet',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.success.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline_rounded,
                                        size: 13, color: AppColors.success),
                                    SizedBox(width: 5),
                                    Text('Secure',
                                        style: TextStyle(
                                            color: AppColors.success,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GlassCard(
                            glowColor: AppColors.violet,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Available balance (USD)',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                AnimatedCounter(
                                  value: data.balance.available,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _Breakdown(
                                          label: 'Available',
                                          value: data.balance.available),
                                    ),
                                    Expanded(
                                      child: _Breakdown(
                                          label: 'Pending',
                                          value: data.balance.pending),
                                    ),
                                    Expanded(
                                      child: _Breakdown(
                                          label: 'Lifetime',
                                          value: data.balance.lifetimeEarned),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: PrimaryButton(
                                        label: 'Deposit',
                                        outlined: true,
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            appRoute(const DepositScreen()),
                                          );
                                          _reload();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: PrimaryButton(
                                        label: 'Withdraw',
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            appRoute(
                                              WithdrawScreen(
                                                availableBalance:
                                                    data.balance.available,
                                              ),
                                            ),
                                          );
                                          _reload();
                                        },
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
                          if (data.txns.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No transactions yet.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                ),
                              ),
                            )
                          else
                            for (final t in data.txns) ...[
                              GlassCard(
                                borderRadius: 18,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: _kindColor(_kind(t))
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Icon(_kindIcon(_kind(t)),
                                          size: 18,
                                          color: _kindColor(_kind(t))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(_title(t),
                                              style: const TextStyle(
                                                  color:
                                                      AppColors.textPrimary,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 13)),
                                          Text(
                                              t.description ??
                                                  (t.status == 'pending'
                                                      ? 'Pending'
                                                      : ''),
                                              style: const TextStyle(
                                                  color: AppColors
                                                      .textSecondary,
                                                  fontSize: 11)),
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
                    );
                  },
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

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Sign in to view your wallet.',
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
              "Couldn't load your wallet.",
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
