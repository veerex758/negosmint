import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/diagnostic_display.dart';
import '../../core/widgets/particle_background.dart';
import '../auth/login_screen.dart';
import '../main_nav/main_nav_screen.dart';
import '../../services/auth_service.dart';
import '../../core/config/supabase_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Object? _navigationError;
  bool _navigating = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final Animation<double> _logoScale = Tween(begin: 0.9, end: 1.0)
      .animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
  ));

  late final Animation<double> _logoOpacity =
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4));

  late final Animation<double> _glowPulse = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 1),
  ]).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
  ));

  late final Animation<double> _textOpacity =
      CurvedAnimation(parent: _controller, curve: const Interval(0.55, 0.85));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 800), _navigate);
  }

  void _navigate() {
    if (!mounted || _navigating) return;
    setState(() => _navigating = true);
    try {
      final destination =
          SupabaseConfig.isConfigured && AuthService.instance.isSignedIn
              ? const MainNavScreen()
              : const LoginScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, anim, __) =>
              FadeTransition(opacity: anim, child: destination),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _navigationError = error;
          _navigating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_navigationError != null) {
      return DiagnosticDisplay(
        title: 'Unable to continue',
        message: 'NegosMint could not open the next screen. '
            'Please retry to continue.\n\n'
            'Diagnostic: ${_navigationError.runtimeType}',
        retryLabel: 'Retry navigation',
        onRetry: _navigate,
      );
    }

    return Scaffold(
      body: ParticleBackground(
        particleCount: 18,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.glowGradient(
                                AppColors.cobalt,
                                opacity: 0.35 * _glowPulse.value,
                              ),
                            ),
                          ),
                          Image.asset(
                            'assets/images/logo.png',
                            width: 112,
                            height: 112,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.brandGradient.createShader(bounds),
                          child: const Text(
                            'NEGOSMINT',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Complete. Earn. Grow.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
