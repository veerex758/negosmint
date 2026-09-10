import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Chrome + cobalt-center coin with slow 3D-style rotation and a soft
/// light sweep. No neon — reflections only.
class AnimatedCoin extends StatefulWidget {
  const AnimatedCoin({super.key, this.size = 96});

  final double size;

  @override
  State<AnimatedCoin> createState() => _AnimatedCoinState();
}

class _AnimatedCoinState extends State<AnimatedCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Simulate 3D rotation by squashing width via sin curve.
        final scaleX = cos(t * 2 * pi).abs().clamp(0.15, 1.0);
        final floatY = sin(t * 2 * pi) * 4;

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scaleByVector3(Vector3(scaleX, 1.0, 1.0)),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE7ECFF),
                    Color(0xFFAFC8FF),
                    AppColors.cobalt,
                    Color(0xFFC9B8FF),
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cobalt.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'NM',
                style: TextStyle(
                  fontSize: widget.size * 0.28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.background.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
