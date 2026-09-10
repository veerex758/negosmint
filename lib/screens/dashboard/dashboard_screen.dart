import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/task_card.dart';
import 'widgets/balance_card.dart';
import 'widgets/streak_card.dart';
import 'widgets/quick_actions.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _tasks = [
    TaskItem(title: 'Complete Survey', category: 'Surveys', reward: 1.50, minutes: 5),
    TaskItem(title: 'Install & Try App', category: 'Apps', reward: 2.25, minutes: 10),
    TaskItem(title: 'Watch Short Video', category: 'Videos', reward: 0.40, minutes: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Hello, Alex!',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Stack(
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          color: AppColors.textPrimary),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.violet,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceElevated,
                    child: Icon(Icons.person, size: 18, color: AppColors.highlight),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const StreakCard(days: 7),
              const SizedBox(height: 16),
              BalanceCard(
                balance: 125.45,
                weeklyChangePct: 12.5,
                onWithdraw: () {},
                onWallet: () {},
              ),
              const SizedBox(height: 20),
              const Text('Quick Actions',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 12),
              QuickActions(onSelect: (_) {}),
              const SizedBox(height: 20),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Earnings Overview',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cobalt.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('7D',
                              style: TextStyle(
                                  color: AppColors.highlight, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('\$45.80',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Icon(Icons.arrow_upward,
                            size: 13, color: AppColors.success),
                        Text(' 12.5%',
                            style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 90,
                      child: CustomPaint(
                        painter: _MiniChartPainter(),
                        size: const Size(double.infinity, 90),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Available Tasks',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 12),
              for (final t in _tasks) ...[
                TaskCard(task: t, onStart: () {}),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [0.3, 0.5, 0.35, 0.6, 0.45, 0.8, 0.7];
    final path = Path();
    final fillPath = Path();
    final dx = size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.cobalt.withOpacity(0.3), AppColors.cobalt.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = AppColors.brandGradient
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
