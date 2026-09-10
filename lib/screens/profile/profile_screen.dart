import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _menu = [
    (icon: Icons.edit_outlined, label: 'Edit Profile'),
    (icon: Icons.shield_outlined, label: 'Account Security'),
    (icon: Icons.notifications_none_rounded, label: 'Notifications'),
    (icon: Icons.public, label: 'Language'),
    (icon: Icons.help_outline_rounded, label: 'Help & Support'),
    (icon: Icons.description_outlined, label: 'Terms'),
    (icon: Icons.privacy_tip_outlined, label: 'Privacy'),
    (icon: Icons.logout_rounded, label: 'Logout'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const Text('Profile',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              GlassCard(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cobalt.withOpacity(0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text('A',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Alex',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 17)),
                    const Text('@alex123',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Expanded(child: _Stat(label: 'Tasks', value: '132')),
                        Expanded(child: _Stat(label: 'Earned', value: '\$482')),
                        Expanded(child: _Stat(label: 'Referrals', value: '18')),
                        Expanded(child: _Stat(label: 'Streak', value: '7')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final item in _menu)
                      ListTile(
                        leading: Icon(item.icon, color: AppColors.highlight),
                        title: Text(item.label,
                            style:
                                const TextStyle(color: AppColors.textPrimary)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary),
                        onTap: () {},
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
