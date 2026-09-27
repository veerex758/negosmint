import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/animated_counter.dart';

class TaskCompletionScreen extends StatefulWidget {
  const TaskCompletionScreen({
    super.key,
    required this.taskTitle,
    required this.reward,
    required this.currencyCode,
    required this.instantApproved,
  });

  final String taskTitle;
  final double reward;
  final String currencyCode;
  final bool instantApproved;

  @override
  State<TaskCompletionScreen> createState() => _TaskCompletionScreenState();
}

class _TaskCompletionScreenState extends State<TaskCompletionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  // Checkmark draws itself over the first ~40% of the timeline.
  late final Animation<double> _checkDraw = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
  );

  // Ring scale-in slightly ahead of the check.
  late final Animation<double> _ringScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
  );

  // Coins burst outward right after the check completes.
  late final Animation<double> _burst = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
  );

  // Text + reward number fade/count in near the end.
  late final Animation<double> _textIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
  );

  late final List<_CoinParticle> _particles = List.generate(
    10,
    (i) => _CoinParticle(Random(i * 17)),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        particleCount: 14,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final p in _particles)
                            _buildCoinParticle(p, _burst.value),
                          Transform.scale(
                            scale: _ringScale.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.brandGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cobalt
                                        .withValues(alpha: 0.4),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CustomPaint(
                              painter: _CheckPainter(progress: _checkDraw.value),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _textIn.value.clamp(0.0, 1.0),
                      child: Column(
                        children: [
                          Text(
                            widget.instantApproved ? 'TASK VERIFIED' : 'PROOF SUBMITTED',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.taskTitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          AnimatedCounter(
                            value: _textIn.value.clamp(0.0, 1.0) * widget.reward,
                            prefix: '+${widget.currencyCode == 'NGN' ? '₦' : r'$'}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                            duration: const Duration(milliseconds: 300),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.instantApproved ? 'Auto-approved and added to your available balance' : 'Pending verification · escrow release within 24 hours',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),
                PrimaryButton(
                  label: 'Back to Tasks',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinParticle(_CoinParticle p, double t) {
    final eased = Curves.easeOut.transform(t);
    final dx = cos(p.angle) * p.distance * eased;
    final dy = sin(p.angle) * p.distance * eased;
    final opacity = (1.0 - t).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: t == 0 ? 0 : opacity,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.highlight, AppColors.cobalt],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinParticle {
  _CoinParticle(Random r)
      : angle = r.nextDouble() * 2 * pi,
        distance = 70 + r.nextDouble() * 60,
        size = 8 + r.nextDouble() * 8;

  final double angle;
  final double distance;
  final double size;
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final p1 = Offset(size.width * 0.18, size.height * 0.52);
    final p2 = Offset(size.width * 0.42, size.height * 0.74);
    final p3 = Offset(size.width * 0.86, size.height * 0.26);

    final firstLegLen = (p2 - p1).distance;
    final secondLegLen = (p3 - p2).distance;
    final totalLen = firstLegLen + secondLegLen;
    final drawLen = totalLen * progress.clamp(0.0, 1.0);

    if (drawLen <= firstLegLen) {
      final t = firstLegLen == 0 ? 0.0 : drawLen / firstLegLen;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      final remaining = drawLen - firstLegLen;
      final t = secondLegLen == 0 ? 0.0 : remaining / secondLegLen;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                            duration: const Duration(milliseconds: 300),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.instantApproved ? 'Auto-approved and added to your available balance' : 'Pending verification · escrow release within 24 hours',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),
                PrimaryButton(
                  label: 'Back to Tasks',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinParticle(_CoinParticle p, double t) {
    final eased = Curves.easeOut.transform(t);
    final dx = cos(p.angle) * p.distance * eased;
    final dy = sin(p.angle) * p.distance * eased;
    final opacity = (1.0 - t).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: t == 0 ? 0 : opacity,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.highlight, AppColors.cobalt],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinParticle {
  _CoinParticle(Random r)
      : angle = r.nextDouble() * 2 * pi,
        distance = 70 + r.nextDouble() * 60,
        size = 8 + r.nextDouble() * 8;

  final double angle;
  final double distance;
  final double size;
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final p1 = Offset(size.width * 0.18, size.height * 0.52);
    final p2 = Offset(size.width * 0.42, size.height * 0.74);
    final p3 = Offset(size.width * 0.86, size.height * 0.26);

    final firstLegLen = (p2 - p1).distance;
    final secondLegLen = (p3 - p2).distance;
    final totalLen = firstLegLen + secondLegLen;
    final drawLen = totalLen * progress.clamp(0.0, 1.0);

    if (drawLen <= firstLegLen) {
      final t = firstLegLen == 0 ? 0.0 : drawLen / firstLegLen;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      final remaining = drawLen - firstLegLen;
      final t = secondLegLen == 0 ? 0.0 : remaining / secondLegLen;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
