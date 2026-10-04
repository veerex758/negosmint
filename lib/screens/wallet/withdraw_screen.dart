import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/crypto_wallet_service.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key, required this.availableBalance});
  final double availableBalance;
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  String _asset = 'USDT';
  String _network = 'POLYGON';
  String? _error;
  bool _submitting = false;
  CryptoWithdrawalResult? _result;

  static const _networks = <String, String>{
    'POLYGON': 'Polygon',
    'BSC': 'BNB Smart Chain',
    'ARBITRUM': 'Arbitrum',
    'BASE': 'Base',
    'ETHEREUM': 'Ethereum',
  };

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (_amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_amount < 5) {
      setState(() => _error = 'Minimum crypto withdrawal is 5 $_asset.');
      return;
    }
    if (_amount > widget.availableBalance) {
      setState(() => _error = 'Amount exceeds your available balance.');
      return;
    }
    final address = _addressController.text.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) {
      setState(() => _error = 'Enter a valid EVM wallet address.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await CryptoWalletService.instance.withdraw(
        amount: _amount,
        asset: _asset,
        network: _network,
        walletAddress: address,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
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
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    ),
                    const Text('Crypto Withdrawal',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(child: _result != null ? _buildSuccess() : _buildForm()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: AppColors.highlight),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Available balance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('${widget.availableBalance.toStringAsFixed(2)} $_asset',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 25, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Asset', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _asset,
            dropdownColor: AppColors.background,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.token)),
            items: const [
              DropdownMenuItem(value: 'USDT', child: Text('USDT')),
              DropdownMenuItem(value: 'USDC', child: Text('USDC')),
            ],
            onChanged: (v) => setState(() => _asset = v ?? 'USDT'),
          ),
          const SizedBox(height: 18),
          const Text('Network', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _network,
            dropdownColor: AppColors.background,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.hub_outlined)),
            items: _networks.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _network = v ?? 'POLYGON'),
          ),
          const SizedBox(height: 18),
          const Text('Wallet address', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            autocorrect: false,
            decoration: const InputDecoration(hintText: '0x...', prefixIcon: Icon(Icons.wallet_outlined)),
          ),
          const SizedBox(height: 8),
          const Text('Paste the receiving address from Trust Wallet. The network must match exactly.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
          const SizedBox(height: 18),
          const Text('Amount', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(hintText: '0.00', suffixText: _asset),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 24),
          const GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Crypto transfers are irreversible after broadcast. Check the address and network before confirming.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                )),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Send Crypto', loading: _submitting, onPressed: _withdraw),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final r = _result!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(width: 82, height: 82,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
              child: const Icon(Icons.check_rounded, color: AppColors.background, size: 44)),
            const SizedBox(height: 20),
            const Text('Crypto Sent',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${r.asset} • ${_networks[r.network] ?? r.network}',
              style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            GlassCard(
              child: Column(children: [
                const Text('Transaction hash', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                SelectableText(r.txHash, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
