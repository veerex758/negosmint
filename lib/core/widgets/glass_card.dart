import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24,
    this.blur = 18,
    this.opacity = 0.12,
    this.borderOpacity = 0.18,
    this.offset = const Offset(0, 20),
    this.duration = const Duration(milliseconds: 500),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final Offset offset;
  final Duration duration;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(curvedAnimation);

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curvedAnimation);

    _scaleAnimation = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(curvedAnimation);

    // Start after the first frame.
    // This avoids creating a Duration.zero timer that Flutter tests
    // can detect as a pending timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(
            widget.offset.dx / 100,
            widget.offset.dy / 100,
          ),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blur,
                sigmaY: widget.blur,
              ),
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: widget.opacity,
                  ),
                  borderRadius: BorderRadius.circular(
                    widget.borderRadius,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: widget.borderOpacity,
                    ),
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}