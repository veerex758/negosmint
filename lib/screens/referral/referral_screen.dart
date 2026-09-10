import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  static const _code = 'NM-ALEX-7F2K';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: ListView(
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Row(
                        children: [
                           Expanded(
                            child: Text(_code,
                                style: TextStyle(
                                    color: AppColors.highlight,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    fontSize: 15)),
                          ),
                          const Icon(Icons.copy_rounded,
                              size: 18, color: AppColors.textSecondary),
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
                              onPressed: () {}),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                              label: 'Share',
                              icon: Icons.share_rounded,
                              onPressed: () {}),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(
                      child: _StatCard(label: 'Total Referrals', value: '18')),
                  SizedBox(width: 12),
                  Expanded(
                      child: _StatCard(label: 'Active Referrals', value: '11')),
                ],
              ),
              const SizedBox(height: 12),
              const _StatCard(label: 'Referral Earnings', value: '\$54.20'),
            ],
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
