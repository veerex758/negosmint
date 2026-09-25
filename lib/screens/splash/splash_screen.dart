import 'package:flutter/material.dart';
import '../auth/login_screen.dart';

const _vaultGreen = Color(0xFF0E2218);
const _sageGreen = Color(0xFF8EA873);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: Curves.outCirc,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(_loginRoute());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Route<void> _loginRoute() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const LoginScreen(),
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
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _vaultGreen,
      body: Center(
        child: FadeTransition(
          opacity: _entrance,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.055),
              end: Offset.zero,
            ).animate(_entrance),
            child: Column(
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
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact, line-built NM mark so the identity stays sharp at every size.
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
