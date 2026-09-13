import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/wallet_service.dart';

enum _WithdrawStep { amount, method, summary, submitted }

class _WithdrawMethod {
  const _WithdrawMethod(this.label, this.icon, this.feeRate, this.detail);
  final String label;
  final IconData icon;
  final double feeRate; // fraction of amount
  final String detail;
}

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key, required this.availableBalance});
  final double availableBalance;

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  _WithdrawStep _step = _WithdrawStep.amount;
  final _amountController = TextEditingController();
  String? _amountError;
  int _methodIndex = 0;
  bool _submitting = false;
  String? _transactionId;


  static const _methods = [
    _WithdrawMethod('Bank Transfer', Icons.account_balance_outlined, 0.02,
        'Arrives in 1–3 business days'),
    _WithdrawMethod('Mobile Money', Icons.phone_iphone_rounded, 0.015,
        'Arrives within minutes'),
    _WithdrawMethod('Other', Icons.more_horiz_rounded, 0.03,
        'Manual review required'),
  ];

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  _WithdrawMethod get _method => _methods[_methodIndex];
  double get _fee => _amount * _method.feeRate;
  double get _youReceive {
    final remainder = _amount - _fee;
    return remainder < 0 ? 0.0 : remainder;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _validateAndContinue() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    if (amount > widget.availableBalance) {
      setState(() => _amountError = 'Amount exceeds available balance');
      return;
    }
    setState(() {
      _amountError = null;
      _step = _WithdrawStep.method;
    });
  }

  Future<void> _confirmWithdrawal() async {
    setState(() => _submitting = true);
    try {
      final ref = await WalletService.instance.requestWithdrawal(
        amount: _amount,
        fee: _fee,
        method: _method.label,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _transactionId = ref;
        _step = _WithdrawStep.submitted;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e.toString().contains('Insufficient balance')
          ? "That's more than your available balance."
          : 'Withdrawal failed. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_step == _WithdrawStep.amount ||
                            _step == _WithdrawStep.submitted) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() {
                            _step = _step == _WithdrawStep.summary
                                ? _WithdrawStep.method
                                : _WithdrawStep.amount;
                          });
                        }
                      },
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Withdraw',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: switch (_step) {
                    _WithdrawStep.amount => _buildAmountStep(),
                    _WithdrawStep.method => _buildMethodStep(),
                    _WithdrawStep.summary => _buildSummaryStep(),
                    _WithdrawStep.submitted => _buildSubmittedStep(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountStep() {
    return SingleChildScrollView(
      key: const ValueKey('amount'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Balance',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '\$${widget.availableBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Enter amount',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
              hintText: '0.00',
              errorText: _amountError,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Continue', onPressed: _validateAndContinue),
        ],
      ),
    );
  }

  Widget _buildMethodStep() {
    return ListView(
      key: const ValueKey('method'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Text('Withdrawal method',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        const SizedBox(height: 12),
        for (var i = 0; i < _methods.length; i++) ...[
          _MethodTile(
            method: _methods[i],
            selected: _methodIndex == i,
            onTap: () => setState(() => _methodIndex = i),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Continue',
          onPressed: () => setState(() => _step = _WithdrawStep.summary),
        ),
      ],
    );
  }

  Widget _buildSummaryStep() {
    return SingleChildScrollView(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Withdrawal Summary',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                _SummaryRow(label: 'Amount', value: '\$${_amount.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                _SummaryRow(label: 'Method', value: _method.label),
                const SizedBox(height: 12),
                _SummaryRow(
                    label: 'Fee (${(_method.feeRate * 100).toStringAsFixed(1)}%)',
                    value: '-\$${_fee.toStringAsFixed(2)}'),
                const Divider(color: AppColors.glassBorder, height: 28),
                _SummaryRow(
                  label: "You'll receive",
                  value: '\$${_youReceive.toStringAsFixed(2)}',
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Confirm Withdrawal',
            loading: _submitting,
            onPressed: _confirmWithdrawal,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedStep() {
    return Center(
      key: const ValueKey('submitted'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success,
              ),
              child:
                  const Icon(Icons.north_east_rounded, color: AppColors.background, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Withdrawal Submitted',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Transaction ID: $_transactionId',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile(
      {required this.method, required this.selected, required this.onTap});
  final _WithdrawMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      borderRadius: 18,
      glowColor: selected ? AppColors.cobalt : null,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.cobalt.withValues(alpha: selected ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(method.icon, color: AppColors.highlight, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.label,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(method.detail,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.highlight : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? AppColors.success : AppColors.textPrimary,
            fontSize: emphasize ? 18 : 14,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
