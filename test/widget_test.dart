import 'package:flutter_test/flutter_test.dart';

import 'package:negosmint/main.dart';

void main() {
  testWidgets('App boots and shows the splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NegosMintApp());
    await tester.pump();

    // Splash screen renders the NEGOSMINT wordmark before navigating away.
    expect(find.text('NEGOSMINT'), findsOneWidget);

    // The splash screen schedules a Future.delayed to auto-navigate to
    // LoginScreen. Advance the (fake) clock past that so the test doesn't
    // end with a pending timer, which flutter_test treats as a failure.
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('Startup failures are displayed and can be retried',
      (WidgetTester tester) async {
    var shouldFail = true;

    await tester.pumpWidget(NegosMintApp(
      initializeServices: () async {
        if (shouldFail) throw StateError('Service initialization failed');
      },
    ));
    await tester.pump();

    expect(find.text('Unable to start NegosMint'), findsOneWidget);
    expect(find.text('Retry startup'), findsOneWidget);
    expect(find.textContaining('StateError'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('Retry startup'));
    await tester.pump();

    expect(find.text('NEGOSMINT'), findsOneWidget);
  });
}
