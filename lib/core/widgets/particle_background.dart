import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable atmospheric background: obsidian-navy gradient, faint moving
/// dots (standing in for a world map), and soft cobalt/violet glow blobs.
/// Kept intentionally subtle and performance-light (no image assets).
class ParticleBackground extends StatefulWidget {
  const ParticleBackground({
    super.key,
    this.particleCount = 26,
    this.child,
  });

  final int particleCount;
  final Widget? child;

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _Particle {
  _Particle(Random r)
      : dx = r.nextDouble(),
        dy = r.nextDouble(),
        radius = 0.6 + r.nextDouble() * 1.6,
        speed = 0.02 + r.nextDouble() * 0.04,
        phase = r.nextDouble() * 2 * pi;

  final double dx, dy, radius, speed, phase;
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  late final List<_Particle> _particles = List.generate(
    widget.particleCount,
    (_) => _Particle(Random()),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        ),
        // Soft glow blobs
        Align(
          alignment: const Alignment(-0.8, -0.9),
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.glowGradient(AppColors.cobalt, opacity: 0.16),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.9, 0.7),
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.glowGradient(AppColors.violet, opacity: 0.14),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ParticlePainter(_particles, _controller.value),
            );
          },
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.highlight.withValues(alpha: 0.35);
    for (final p in particles) {
      final y = (p.dy + sin(t * 2 * pi + p.phase) * 0.02) % 1.0;
      final x = (p.dx + p.speed * t) % 1.0;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
