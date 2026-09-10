import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:negosmint/main.dart';

void main() {
  setUpAll(() {
    // google_fonts tries to fetch font files over the network at runtime.
    // CI test environments block network access, which throws mid-build
    // and fails the test even when the actual assertions are correct.
    // Disabling runtime fetching falls back to the system font instead.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('App boots and shows the splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NegosMintApp());

    // Splash screen renders the NEGOSMINT wordmark before navigating away.
    expect(find.text('NEGOSMINT'), findsOneWidget);

    // The splash screen schedules a Future.delayed to auto-navigate to
    // LoginScreen. Advance the (fake) clock past that so the test doesn't
    // end with a pending timer, which flutter_test treats as a failure.
    await tester.pump(const Duration(milliseconds: 2500));
  });
}