import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../services/task_service.dart';
import '../../services/referral_service.dart';
import '../../models/app_profile.dart';
import '../../models/referral_stats.dart';
import '../../models/wallet_transaction.dart';
import '../auth/login_screen.dart';

typedef _ProfileData = ({
  AppProfile? profile,
  double lifetimeEarned,
  int tasksCompleted,
  int referrals,
  int streak,
});

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<_ProfileData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_ProfileData>? _load() {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return null;
    return () async {
      final results = await Future.wait([
        AuthService.instance.fetchCurrentProfile(),
        WalletService.instance.fetchBalance(userId),
        TaskService.instance.fetchCompletedCount(userId),
        ReferralService.instance.fetchStats(userId),
        AuthService.instance.fetchStreak(userId),
      ]);
      final balance = results[1] as WalletBalance;
      final referralStats = results[3] as ReferralStats;
      return (
        profile: results[0] as AppProfile?,
        lifetimeEarned: balance.lifetimeEarned,
        tasksCompleted: results[2] as int,
        referrals: referralStats.totalReferrals,
        streak: results[4] as int,
      );
    }();
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      appRoute(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = [
      (icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () {}),
      (icon: Icons.shield_outlined, label: 'Account Security', onTap: () {}),
      (
        icon: Icons.notifications_none_rounded,
        label: 'Notifications',
        onTap: () {}
      ),
      (icon: Icons.public, label: 'Language', onTap: () {}),
      (icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () {}),
      (icon: Icons.description_outlined, label: 'Terms', onTap: () {}),
      (icon: Icons.privacy_tip_outlined, label: 'Privacy', onTap: () {}),
      (
        icon: Icons.logout_rounded,
        label: 'Logout',
        onTap: () => _logout(context)
      ),
    ];

    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: _dataFuture == null
              ? _SignedOutState(onLogout: () => _logout(context))
              : FutureBuilder<_ProfileData>(
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
                          onPressed: () =>
                              setState(() => _dataFuture = _load()),
                          child: const Text("Couldn't load profile — Retry",
                              style: TextStyle(color: AppColors.highlight)),
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    final name = data.profile?.fullName ?? 'Your Profile';
                    final username = data.profile?.username;
                    final initial =
                        name.isNotEmpty ? name[0].toUpperCase() : '?';

                    return ListView(
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
                                      color: AppColors.cobalt
                                          .withValues(alpha: 0.3),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(initial,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(height: 12),
                              Text(name,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17)),
                              if (username != null)
                                Text('@$username',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                      child: _Stat(
                                          label: 'Tasks',
                                          value: '${data.tasksCompleted}')),
                                  Expanded(
                                      child: _Stat(
                                          label: 'Earned',
                                          value:
                                              '\$${data.lifetimeEarned.toStringAsFixed(0)}')),
                                  Expanded(
                                      child: _Stat(
                                          label: 'Referrals',
                                          value: '${data.referrals}')),
                                  Expanded(
                                      child: _Stat(
                                          label: 'Streak',
                                          value: '${data.streak}')),
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
                              for (final item in menu)
                                ListTile(
                                  leading: Icon(item.icon,
                                      color: AppColors.highlight),
                                  title: Text(item.label,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary)),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textSecondary),
                                  onTap: item.onTap,
                                ),
                            ],
                          ),
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

class _SignedOutState extends StatelessWidget {
  const _SignedOutState({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Not signed in.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onLogout,
              child: const Text('Back to Login',
                  style: TextStyle(color: AppColors.highlight)),
            ),
          ],
        ),
      ),
    );
  }
}
