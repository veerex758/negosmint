import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/connected_wallet.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_connection_service.dart';

class ConnectWalletScreen extends StatefulWidget {
  const ConnectWalletScreen({super.key});

  @override
  State<ConnectWalletScreen> createState() => _ConnectWalletScreenState();
}

class _ConnectWalletScreenState extends State<ConnectWalletScreen> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  ConnectedWallet? _wallet;
  String? _pendingRequestId;
  String? _error;
  bool _loading = true;
  bool _connecting = false;

  String? get _userId => AuthService.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _subscription = _appLinks.uriLinkStream.listen(_handleCallback, onError: (_) {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }
    try {
      final wallet = await WalletConnectionService.instance.fetchConnectedWallet(userId);
      if (mounted) {
        setState(() {
          _wallet = wallet;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    if (_userId == null) {
      setState(() {
        _error = 'Sign in before connecting a wallet.';
      });
      return;
    }

    setState(() {
      _error = null;
      _connecting = true;
    });

    try {
      final payload = WalletConnectionService.instance.createConnectionRequest();
      final uri = Uri.parse(payload);
      final encoded = uri.queryParameters['request'];
      if (encoded == null) {
        throw const WalletConnectionException('Invalid wallet request.');
      }

      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      ) as Map<String, dynamic>;
      _pendingRequestId = decoded['requestId'] as String?;

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const WalletConnectionException(
          'NegosMint Wallet could not be opened. Make sure the wallet app is installed.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleCallback(Uri uri) async {
    if (uri.scheme != 'negosmint' || uri.host != 'wallet') {
      return;
    }
    final encoded = uri.queryParameters['result'];
    final requestId = _pendingRequestId;
    if (encoded == null || requestId == null) {
      return;
    }

    try {
      final result = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      ) as Map<String, dynamic>;
      final userId = _userId;
      if (userId == null) {
        return;
      }

      await WalletConnectionService.instance.saveApprovedConnection(
        userId: userId,
        result: result,
        expectedRequestId: requestId,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _pendingRequestId = null;
      });
      await _loadWallet();
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _disconnect() async {
    final userId = _userId;
    if (userId == null) {
        return;
      }
    await WalletConnectionService.instance.disconnect(userId);
    if (mounted) {
      setState(() {
        _wallet = null;
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
              ? const Center(child: CircularProgressIndicator(color: AppColors.highlight))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                        ),
                        const Expanded(
                          child: Text('NegosMint Wallet',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: AppColors.highlight, size: 30),
                          const SizedBox(height: 12),
                          const Text('Self-custody wallet',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(
                            _wallet == null
                                ? 'Connect the separate NegosMint Wallet. Your recovery phrase and private key stay inside the wallet app.'
                                : 'Connected. Only your public wallet address and connection metadata are stored here.',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                          ),
                          if (_wallet != null) ...[
                            const SizedBox(height: 18),
                            _InfoRow('Address', _short(_wallet!.walletAddress)),
                            _InfoRow('Network', _wallet!.network),
                            _InfoRow('Chain ID', _wallet!.chainId.toString()),
                            const SizedBox(height: 16),
                            PrimaryButton(label: 'Disconnect Wallet', outlined: true, onPressed: _disconnect),
                          ] else ...[
                            const SizedBox(height: 18),
                            PrimaryButton(
                              label: _connecting ? 'Waiting for wallet…' : 'Connect NegosMint Wallet',
                              loading: _connecting,
                              onPressed: _connecting ? null : _connect,
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.warning, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Connection starts on Sepolia testnet. Never send a recovery phrase, private key, PIN, or seed to the task platform.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45),
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
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(width: 86, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))),
            Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
