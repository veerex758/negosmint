import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

void main() {
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
