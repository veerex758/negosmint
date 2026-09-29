import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'particle_background.dart';
import 'primary_button.dart';

/// Recoverable error state for startup or navigation failures.
class DiagnosticDisplay extends StatelessWidget {
  const DiagnosticDisplay({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try again',
    this.retrying = false,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 44),
                    const SizedBox(height: 16),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 10),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        )),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: retryLabel,
                      icon: Icons.refresh_rounded,
                      loading: retrying,
                      onPressed: retrying ? null : onRetry,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
