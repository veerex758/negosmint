import 'package:flutter/material.dart';

/// Animates a dollar amount smoothly between old and new values whenever
/// [value] changes, instead of jumping instantly (e.g. balance updates).
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '\$',
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String prefix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text('$prefix${v.toStringAsFixed(2)}', style: style);
      },
    );
  }
}
