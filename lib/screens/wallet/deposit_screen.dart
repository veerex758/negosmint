import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/config/stripe_config.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/deposit_service.dart';

enum _DepositStep { amount, submitted }

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  _DepositStep _step = _DepositStep.amount;
  final _amountController = TextEditingController();
  String? _amountError;
  bool _processing = false;
  double _depositedAmount = 0;

  static const minimumDeposit = 5.0;
  static const maximumDeposit = 10000.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _startDeposit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    if (amount < minimumDeposit) {
      setState(() => _amountError =
          'Minimum deposit is \$${minimumDeposit.toStringAsFixed(2)}');
      return;
    }
    if (amount > maximumDeposit) {
      setState(() => _amountError =
          'Maximum deposit is \$${maximumDeposit.toStringAsFixed(2)}');
      return;
    }

    if (!StripeConfig.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Deposits are not configured on this build.')),
      );
      return;
    }

    setState(() {
      _amountError = null;
      _processing = true;
    });

    try {
      final intent = await DepositService.instance.createPaymentIntent(amount);

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          customerEphemeralKeySecret: intent.ephemeralKey,
          customerId: intent.customerId,
          merchantDisplayName: 'NegosMint',
          style: ThemeMode.dark,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // The sheet closing without throwing means Stripe's client SDK
      // saw success — but the server re-verifies before crediting
      // anything. See confirm-deposit/index.ts for why.
      final credited =
          await DepositService.instance.confirmDeposit(intent.paymentIntentId);

      if (!mounted) return;
      if (credited) {
        setState(() {
          _depositedAmount = amount;
          _step = _DepositStep.submitted;
          _processing = false;
        });
      } else {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Payment is still processing — check back in a moment.")),
        );
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      // FailureCode.Canceled means the user closed the sheet themselves
      // — not an error worth showing as one.
      if (e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.error.localizedMessage ?? 'Payment failed.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Deposit',
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
                  child: _step == _DepositStep.amount
                      ? _buildAmountStep()
                      : _buildSubmittedStep(),
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
          const SizedBox(height: 16),
          GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: AppColors.highlight),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payments are processed securely by Stripe. Card details never touch NegosMint servers.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Continue',
            loading: _processing,
            onPressed: _startDeposit,
          ),
          const SizedBox(height: 12),
          Text(
            'Minimum \$${minimumDeposit.toStringAsFixed(2)} · Maximum \$${maximumDeposit.toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
              child: const Icon(Icons.check, color: AppColors.background, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Deposit Successful',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '\$${_depositedAmount.toStringAsFixed(2)} added to your wallet',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
