import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/app_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<AppNotification>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>>? _load() {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return null;
    return NotificationService.instance.fetchNotifications(userId);
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.read) return;
    await NotificationService.instance.markRead(n.id);
    if (!mounted) return;
    setState(() => _future = _load());
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'withdrawal_update':
        return Icons.north_east_rounded;
      case 'new_task':
        return Icons.bolt_rounded;
      case 'referral_reward':
        return Icons.groups_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}/${time.year}';
  }

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
                child: _future == null
                    ? const Center(
                        child: Text(
                          'Sign in to view your notifications.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : FutureBuilder<List<AppNotification>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.highlight),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _future = _load()),
                                child: const Text(
                                    "Couldn't load notifications — Retry",
                                    style:
                                        TextStyle(color: AppColors.highlight)),
                              ),
                            );
                          }
                          final items = snapshot.data ?? const [];
                          if (items.isEmpty) {
                            return const Center(
                              child: Text(
                                'No notifications yet.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              return GlassCard(
                                borderRadius: 18,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                delay: Duration(milliseconds: 40 * i),
                                onTap: () => _markRead(item),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.cobalt
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Icon(_iconFor(item.type),
                                          size: 18,
                                          color: AppColors.highlight),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(item.title,
                                                    style: const TextStyle(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13)),
                                              ),
                                              Text(_timeAgo(item.createdAt),
                                                  style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(item.body,
                                              style: const TextStyle(
                                                  color: AppColors
                                                      .textSecondary,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (!item.read) ...[
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
