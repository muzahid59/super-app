// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ocr_app/main.dart';

void main() {
  testWidgets('Receipt Scanner app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our transaction list screen loads
    expect(find.text('Receipt Scanner'), findsOneWidget);

    // Verify the empty state message appears
    await tester.pumpAndSettle();
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('Tap + to scan a receipt'), findsOneWidget);
  });
}
