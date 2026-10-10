import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_verification_service.dart';

class ConnectWalletScreen extends StatefulWidget {
  const ConnectWalletScreen({super.key});

  @override
  State<ConnectWalletScreen> createState() => _ConnectWalletScreenState();
}

class _ConnectWalletScreenState extends State<ConnectWalletScreen> {
  WalletVerificationResult? _verifiedWallet;
  String? _error;
  bool _loading = true;
  bool _connecting = false;

  String? get _userId => AuthService.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    if (_userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Sign in before verifying a wallet.';
        });
      }
      return;
    }

    try {
      final wallet =
          await WalletVerificationService.instance.fetchVerifiedWallet();
      if (!mounted) return;
      setState(() {
        _verifiedWallet = wallet;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the verified wallet status. Try again.';
      });
    }
  }

  Future<void> _connect() async {
    if (_userId == null) {
      setState(() => _error = 'Sign in before verifying a wallet.');
      return;
    }

    setState(() {
      _error = null;
      _connecting = true;
    });

    try {
      final service = WalletVerificationService.instance;
      final challenge = await service.createChallenge();
      final handoffResult =
          await service.launchWalletOwnershipHandoff(challenge);
      final verified = await service.completeOwnershipHandoff(
        challenge: challenge,
        handoffResult: handoffResult,
      );

      if (!mounted) return;
      setState(() {
        _verifiedWallet = verified;
        _connecting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = error
            .toString()
            .replaceFirst('WalletConnectionException: ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  String _short(String address) =>
      '${address.substring(0, 6)}…${address.substring(address.length - 4)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.highlight,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'NegosMint Wallet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.highlight,
                            size: 30,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Self-custody wallet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _verifiedWallet == null
                                ? 'Verify ownership using the separate NegosMint Wallet. Your recovery phrase and private key stay inside that app.'
                                : 'Wallet ownership has been verified by the server. Only your public address and verification metadata are stored here.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          if (_verifiedWallet != null) ...[
                            const SizedBox(height: 18),
                            const _InfoRow(
                              'Status',
                              'Verified',
                              valueColor: AppColors.highlight,
                            ),
                            _InfoRow(
                              'Address',
                              _short(_verifiedWallet!.address),
                            ),
                            const _InfoRow('Network', 'Ethereum Sepolia'),
                            _InfoRow(
                              'Chain ID',
                              _verifiedWallet!.chainId.toString(),
                            ),
                          ],
                          const SizedBox(height: 18),
                          PrimaryButton(
                            label: _connecting
                                ? 'Waiting for wallet…'
                                : _verifiedWallet == null
                                    ? 'Verify NegosMint Wallet'
                                    : 'Re-verify Wallet Ownership',
                            loading: _connecting,
                            onPressed: _connecting ? null : _connect,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Verification uses a short-lived signed message on Sepolia. It does not send funds or authorize a transaction. Never share a recovery phrase, private key, PIN, or seed with the task platform.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
    this.label,
    this.value, {
    this.valueColor = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 86,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
