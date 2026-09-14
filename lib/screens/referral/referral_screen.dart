import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/auth_service.dart';
import '../../services/referral_service.dart';
import '../../models/app_profile.dart';
import '../../models/referral_stats.dart';

typedef _ReferralData = ({AppProfile profile, ReferralStats stats});

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Future<_ReferralData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_ReferralData>? _load() {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return null;
    return () async {
      final profile = await AuthService.instance.fetchCurrentProfile();
      final stats = await ReferralService.instance.fetchStats(userId);
      if (profile == null) throw Exception('Profile not found');
      return (profile: profile, stats: stats);
    }();
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied.')),
    );
  }

  void _shareCode(String code) {
    SharePlus.instance.share(
      ShareParams(
        text:
            "Join me on NegosMint and start earning! Use my referral code $code when you sign up.",
        subject: 'Join NegosMint',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: _dataFuture == null
              ? const _SignedOutState()
              : FutureBuilder<_ReferralData>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.highlight),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton(
                          onPressed: () => setState(() => _dataFuture = _load()),
                          child: const Text("Couldn't load referrals — Retry",
                              style: TextStyle(color: AppColors.highlight)),
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      children: [
                        const Text('Referrals',
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
                              ShaderMask(
                                shaderCallback: (b) =>
                                    AppColors.brandGradient.createShader(b),
                                child: const Text(
                                  'Invite Friends\nEarn More',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.background.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: AppColors.glassBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(data.profile.referralCode,
                                          style: const TextStyle(
                                              color: AppColors.highlight,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                              fontSize: 15)),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          _copyCode(data.profile.referralCode),
                                      child: const Icon(Icons.copy_rounded,
                                          size: 18,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: PrimaryButton(
                                      label: 'Copy Code',
                                      outlined: true,
                                      onPressed: () =>
                                          _copyCode(data.profile.referralCode),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: PrimaryButton(
                                      label: 'Share',
                                      icon: Icons.share_rounded,
                                      onPressed: () =>
                                          _shareCode(data.profile.referralCode),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Total Referrals',
                                value: '${data.stats.totalReferrals}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Referral Earnings',
                                value:
                                    '\$${data.stats.totalEarnings.toStringAsFixed(2)}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ],
      ),
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
          'Sign in to view your referrals.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}
