import 'package:flutter_test/flutter_test.dart';

import 'package:negosmint/main.dart';

void main() {
  testWidgets('App boots and shows the splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NegosMintApp());

    // Splash screen renders the NEGOSMINT wordmark before navigating away.
    expect(find.text('NEGOSMINT'), findsOneWidget);

    // The splash screen schedules a Future.delayed to auto-navigate to
    // LoginScreen. Advance the (fake) clock past that.
    await tester.pump(const Duration(milliseconds: 2500));

    // LoginScreen's GlassCard schedules its own entrance-animation timer
    // (delay: Duration.zero) as soon as it's built. Flush it so no timer
    // is left pending when the test ends.
    await tester.pump();
  });
}