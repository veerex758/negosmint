import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Brand-gradient button. Tap → scale down + glow up → release → settle.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            },
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: widget.outlined ? null : AppColors.brandGradient,
            color: widget.outlined ? Colors.transparent : null,
            border: widget.outlined
                ? Border.all(color: AppColors.glassBorder)
                : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.outlined || disabled
                ? []
                : [
                    BoxShadow(
                      color: AppColors.cobalt
                          .withOpacity(_pressed ? 0.45 : 0.28),
                      blurRadius: _pressed ? 26 : 18,
                      spreadRadius: _pressed ? 1 : 0,
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(AppColors.textPrimary),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
