import 'package:flutter_test/flutter_test.dart';

import 'package:negosmint/main.dart';

void main() {
  testWidgets('App boots and reaches the login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NegosMintApp());

    // Splash screen renders the NEGOSMINT wordmark before navigating away.
    expect(find.text('NEGOSMINT'), findsOneWidget);

    // Advance through the splash and its route transition so the test proves
    // the app reaches an interactive screen rather than remaining stuck.
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
