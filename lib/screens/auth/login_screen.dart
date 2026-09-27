import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/auth_service.dart';
import '../main_nav/main_nav_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _language = 'English';

  late final AnimationController _sheetController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );
  late final Animation<Offset> _sheetSlide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _sheetController, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _sheetController.forward();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(appRoute(const MainNavScreen()));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickLanguage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF7F6F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            for (final lang in ['English', 'Español', 'Français', 'Filipino'])
              ListTile(
                title: Text(lang,
                    style: const TextStyle(color: Color(0xFF193325))),
                trailing: lang == _language
                    ? const Icon(Icons.check, color: Color(0xFF547047))
                    : null,
                onTap: () {
                  setState(() => _language = lang);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E2218),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NEGOSMINT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickLanguage,
                        icon: Icon(Icons.language_outlined,
                            size: 17,
                            color: Colors.white.withValues(alpha: 0.72)),
                        label: Text(
                          _language,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    'Welcome back!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to continue.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: 212,
            child: SlideTransition(
              position: _sheetSlide,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F6F2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sign in to your account',
                            style: TextStyle(
                              color: Color(0xFF193325),
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your progress and earnings are waiting.',
                            style: TextStyle(color: Color(0xFF657067)),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Color(0xFF193325)),
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              filled: true,
                              fillColor: Color(0xFFFFFFFF),
                              prefixIcon: Icon(Icons.mail_outline,
                                  color: Color(0xFF657067)),
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            style: const TextStyle(color: Color(0xFF193325)),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              filled: true,
                              fillColor: const Color(0xFFFFFFFF),
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: Color(0xFF657067)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF657067),
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Password must be at least 6 characters'
                                : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Forgot password?',
                                  style: TextStyle(color: Color(0xFF547047))),
                            ),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Login',
                            loading: _loading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account?",
                                  style:
                                      TextStyle(color: Color(0xFF657067))),
                              TextButton(
                                onPressed: () => Navigator.of(context)
                                    .push(appRoute(const RegisterScreen())),
                                child: const Text('Create account',
                                    style: TextStyle(
                                        color: Color(0xFF547047),
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
