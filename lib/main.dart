import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'core/config/supabase_config.dart';
import 'core/config/stripe_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Render a frame before initializing optional native SDKs. Waiting for a
  // plugin here can leave Android on the splash screen long enough for the
  // OS to report that the app is not responding.
  runApp(const NegosMintApp());
  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  // Skips cleanly (rather than throwing) when SUPABASE_URL/ANON_KEY weren't
  // passed via --dart-define, such as during `flutter test`.
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // supabase_flutter renamed `anonKey` to `publishableKey` to match
        // Supabase's newer API key naming — same value, new parameter name.
        publishableKey: SupabaseConfig.anonKey,
      );
    } catch (_) {
      // A configuration or native-SDK failure must not prevent the app from
      // becoming interactive. Auth actions will report their own failure.
    }
  }

  // Same skip-cleanly reasoning as Supabase above — the Deposit screen
  // checks StripeConfig.isConfigured itself before trying to use it.
  if (StripeConfig.isConfigured) {
    try {
      Stripe.publishableKey = StripeConfig.publishableKey;
      await Stripe.instance.applySettings();
    } catch (_) {
      // The deposit flow validates Stripe configuration before it is used.
    }
  }
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
