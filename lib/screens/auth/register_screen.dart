import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/app_page_route.dart';
import '../../services/auth_service.dart';
import '../main_nav/main_nav_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _referral = TextEditingController();

  bool _obscure = true;
  bool _agreed = false;
  bool _loading = false;
  bool _success = false;

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _username,
      _email,
      _phone,
      _password,
      _confirmPassword,
      _referral
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms & Conditions')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.signUp(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        username: _username.text.trim(),
        phone: _phone.text.trim(),
        referralCode: _referral.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = true;
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(appRoute(const MainNavScreen()));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: AppColors.textSecondary),
          suffixIcon: suffix,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        body: ParticleBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                    ),
                    child: const Icon(Icons.check,
                        color: AppColors.background, size: 44),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Account created',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                  ),
                  const Text(
                    'Create account',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text('Join NegosMint and start earning.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      children: [
                        _field(
                          controller: _fullName,
                          hint: 'Full name',
                          icon: Icons.badge_outlined,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        _field(
                          controller: _username,
                          hint: 'Username',
                          icon: Icons.alternate_email,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        _field(
                          controller: _email,
                          hint: 'Email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                        ),
                        _field(
                          controller: _phone,
                          hint: 'Phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        _field(
                          controller: _password,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'At least 6 characters'
                              : null,
                        ),
                        _field(
                          controller: _confirmPassword,
                          hint: 'Confirm password',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          validator: (v) => v != _password.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                        _field(
                          controller: _referral,
                          hint: 'Referral code (optional)',
                          icon: Icons.card_giftcard_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        activeColor: AppColors.cobalt,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'I agree to the Terms & Conditions',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Create account',
                    loading: _loading,
                    onPressed: _handleRegister,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
