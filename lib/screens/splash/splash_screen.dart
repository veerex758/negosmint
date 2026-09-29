import 'package:flutter/material.dart';
import '../../core/widgets/diagnostic_display.dart';
import '../auth/login_screen.dart';
import '../main_nav/main_nav_screen.dart';
import '../../services/auth_service.dart';
import '../../core/config/supabase_config.dart';

const _vaultGreen = Color(0xFF0E2218);
const _sageGreen = Color(0xFF8EA873);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Object? _navigationError;
  bool _navigating = false;
  bool _exiting = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final AnimationController _exitController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _exitOpacity = CurvedAnimation(
    parent: _exitController,
    curve: Curves.easeInCubic,
  );

  late final Animation<double> _exitScale = Tween<double>(
    begin: 1,
    end: 0.88,
  ).animate(CurvedAnimation(
    parent: _exitController,
    curve: Curves.easeInCubic,
  ));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2200), _beginExit);
  }

  Future<void> _beginExit() async {
    if (!mounted || _navigating || _exiting) return;
    setState(() => _exiting = true);
    await _exitController.forward();
    if (mounted) _navigate();
  }

  void _navigate() {
    if (!mounted || _navigating) return;
    setState(() => _navigating = true);
    try {
      final destination =
          SupabaseConfig.isConfigured && AuthService.instance.isSignedIn
              ? const MainNavScreen()
              : const LoginScreen();
      Navigator.of(context).pushReplacement(_loginRoute(destination));
    } catch (error) {
      if (mounted) {
        setState(() {
          _navigationError = error;
          _navigating = false;
        });
      }
    }
  }

  Route<void> _loginRoute(Widget destination) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 720),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                child: child,
              ),
            ),
          );
        },
      );

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
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

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _MonogramEmblem(size: 126),
        const SizedBox(height: 30),
        const Text(
          'NEGOSMINT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Complete. Earn. Grow.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            letterSpacing: 0.35,
          ),
        ),
      ],
    );

    final entranceContent = FadeTransition(
      opacity: _entrance,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.055),
          end: Offset.zero,
        ).animate(_entrance),
        child: content,
      ),
    );

    final exitingContent = FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_exitOpacity),
      child: ScaleTransition(
        scale: _exitScale,
        child: entranceContent,
      ),
    );

    return Scaffold(
      backgroundColor: _vaultGreen,
      body: Center(
        child: _exiting ? exitingContent : entranceContent,
      ),
    );
  }
}

class _MonogramEmblem extends StatelessWidget {
  const _MonogramEmblem({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF10291D),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _sageGreen.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: _sageGreen.withValues(alpha: 0.13),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.55),
          painter: _MonogramPainter(),
        ),
      ),
    );
  }
}

class _MonogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD9E6C8)
      ..strokeWidth = size.width * 0.095
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final n = Path()
      ..moveTo(size.width * .08, size.height * .86)
      ..lineTo(size.width * .08, size.height * .14)
      ..lineTo(size.width * .46, size.height * .86)
      ..lineTo(size.width * .46, size.height * .14);
    final m = Path()
      ..moveTo(size.width * .54, size.height * .86)
      ..lineTo(size.width * .54, size.height * .14)
      ..lineTo(size.width * .77, size.height * .52)
      ..lineTo(size.width * .96, size.height * .14)
      ..lineTo(size.width * .96, size.height * .86);
    canvas.drawPath(n, paint);
    canvas.drawPath(m, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
