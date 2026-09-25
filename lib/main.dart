import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'core/config/supabase_config.dart';
import 'core/config/stripe_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/diagnostic_display.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NegosMintApp());
}

/// Initializes optional third-party services before their screens use them.
Future<void> initializeAppServices() async {
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
}

class NegosMintApp extends StatefulWidget {
  const NegosMintApp({
    super.key,
    this.initializeServices = initializeAppServices,
  });

  final Future<void> Function() initializeServices;

  @override
  State<NegosMintApp> createState() => _NegosMintAppState();
}

class _NegosMintAppState extends State<NegosMintApp> {
  Object? _startupError;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _startupError = null;
    });
    try {
      await widget.initializeServices();
    } catch (error) {
      _startupError = error;
    }
    if (mounted) setState(() => _initializing = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NegosMint',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _initializing
          ? const _StartupLoadingScreen()
          : _startupError != null
              ? DiagnosticDisplay(
                  title: 'Unable to start NegosMint',
                  message: 'The app could not finish starting. '
                      'Check your connection and configuration, then retry.\n\n'
                      'Diagnostic: ${_startupError.runtimeType}',
                  retryLabel: 'Retry startup',
                  onRetry: _initialize,
                )
              : const SplashScreen(),
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
