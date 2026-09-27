import 'package:flutter_test/flutter_test.dart';

import 'package:negosmint/main.dart';

void main() {
  testWidgets('App boots and reaches the latest login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(NegosMintApp(
      initializeServices: () async {},
    ));
    await tester.pump();

    expect(find.text('NEGOSMINT'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
  });

  testWidgets('Startup error can be retried',
      (WidgetTester tester) async {
    var shouldError = true;

    await tester.pumpWidget(NegosMintApp(
      initializeServices: () async {
        if (shouldError) throw StateError('Service initialization error');
      },
    ));
    await tester.pump();

    expect(find.text('Unable to start NegosMint'), findsOneWidget);
    expect(find.text('Retry startup'), findsOneWidget);

    shouldError = false;
    await tester.tap(find.text('Retry startup'));
    await tester.pump();

    expect(find.text('NEGOSMINT'), findsOneWidget);
  });
}
