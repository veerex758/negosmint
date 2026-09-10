import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable glass panel: translucent surface + blur + thin border + soft glow.
/// Entrance animation: fade + slide-up + slight scale.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.glowColor,
    this.delay = Duration.zero,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? glowColor;
  final Duration delay;
  final VoidCallback? onTap;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<double> _scale = Tween(begin: 0.97, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // A zero-duration Future.delayed creates a Timer that fires on the
    // same microtask turn — flutter_test can still catch it as "pending"
    // if a test ends before that turn completes. Starting from a
    // post-frame callback avoids creating a timer at all for the common
    // (no-delay) case; a non-zero delay still uses Future.delayed since
    // that's a real, deliberate stagger (e.g. QuickActions grid items).
    if (widget.delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward();
      });
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? AppColors.cobalt;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTapDown: widget.onTap == null
                ? null
                : (_) => setState(() => _pressed = true),
            onTapUp: widget.onTap == null
                ? null
                : (_) {
                    setState(() => _pressed = false);
                    widget.onTap!();
                  },
            onTapCancel: widget.onTap == null
                ? null
                : () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: _pressed ? 0.22 : 0.12),
                      blurRadius: 30,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: widget.padding,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.55),
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}