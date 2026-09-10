import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint/main.dart';

void main() {
  testWidgets(
    'App boots and shows the splash screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(const NegosMintApp());
      expect(
        find.text('NEGOSMINT'),
        findsOneWidget,
        timeout: const Duration(seconds: 10),  // Wait up to 10 seconds
      );
    },
  );
}