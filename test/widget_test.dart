import 'package:flutter_test/flutter_test.dart';

import 'package:negosmint/main.dart';

void main() {
  testWidgets(
    'App boots and shows the splash screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(const NegosMintApp());

      // Splash screen should display immediately.
      expect(find.text('NEGOSMINT'), findsOneWidget);

      // Move past the splash screen delay.
      await tester.pump(const Duration(milliseconds: 2500));

      // Allow the LoginScreen and GlassCard to build.
      await tester.pump();

      // Allow entrance animation to complete.
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}