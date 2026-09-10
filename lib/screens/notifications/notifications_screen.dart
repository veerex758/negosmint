import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    this.unread = false,
  });

  final String title;
  final String body;
  final String time;
  final IconData icon;
  final bool unread;
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _items = [
    _NotificationItem(
      title: 'Task Completed',
      body: 'You earned \$2.50 from Watch Short Video.',
      time: '2m ago',
      icon: Icons.check_circle_outline,
      unread: true,
    ),
    _NotificationItem(
      title: 'Withdrawal Update',
      body: 'Your withdrawal is processing.',
      time: '1h ago',
      icon: Icons.north_east_rounded,
      unread: true,
    ),
    _NotificationItem(
      title: 'New Task',
      body: 'A new task is available in Surveys.',
      time: '3h ago',
      icon: Icons.bolt_rounded,
    ),
    _NotificationItem(
      title: 'Referral Reward',
      body: 'You earned a referral reward from @jordan.',
      time: 'Yesterday',
      icon: Icons.groups_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Notifications',
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
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    return GlassCard(
                      borderRadius: 18,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      delay: Duration(milliseconds: 40 * i),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.cobalt.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.icon,
                                size: 18, color: AppColors.highlight),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(item.title,
                                          style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                    ),
                                    Text(item.time,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(item.body,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          if (item.unread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.violet,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
