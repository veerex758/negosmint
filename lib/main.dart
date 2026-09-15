import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'core/config/supabase_config.dart';
import 'core/config/stripe_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Skips cleanly (rather than throwing) when SUPABASE_URL/ANON_KEY
  // weren't passed via --dart-define — e.g. during `flutter test`, or if
  // someone runs the app before setting up their own Supabase project.
  // Screens that need a signed-in user still work in that case; they'll
  // just get an auth error when a network call is actually attempted.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // supabase_flutter renamed `anonKey` to `publishableKey` to match
      // Supabase's newer API key naming — same value, new parameter name.
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  // Same skip-cleanly reasoning as Supabase above — the Deposit screen
  // checks StripeConfig.isConfigured itself before trying to use it.
  if (StripeConfig.isConfigured) {
    Stripe.publishableKey = StripeConfig.publishableKey;
    await Stripe.instance.applySettings();
  }

  runApp(const NegosMintApp());
}

class NegosMintApp extends StatelessWidget {
  const NegosMintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NegosMint',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
