import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:negosmint/main.dart';

void main() {
  testWidgets('App boots and shows the splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NegosMintApp());

    // Splash screen renders the NEGOSMINT wordmark before navigating away.
    expect(find.text('NEGOSMINT'), findsOneWidget);
  });
}
