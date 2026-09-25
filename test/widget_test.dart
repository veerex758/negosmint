import 'package:flutter_test/flutter_test.dart';

import 'package:negosmint/main.dart';

void main() {
  testWidgets('App boots and shows the splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NegosMintApp());

    // Splash screen renders the NEGOSMINT wordmark before navigating away.
    expect(find.text('NEGOSMINT'), findsOneWidget);

    // The splash screen schedules a Future.delayed to auto-navigate to
    // LoginScreen. Advance the (fake) clock past the splash delay so the test doesn't
    // end with a pending timer, which flutter_test treats as a failure.
    await tester.pump(const Duration(milliseconds: 1200));
  });
}
