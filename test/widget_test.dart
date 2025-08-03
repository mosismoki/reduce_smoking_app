import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reduce_smoking_app/main.dart';

void main() {
  testWidgets('Accept terms enables continue and navigates', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Terms and Conditions'), findsOneWidget);

    final checkbox = find.byType(Checkbox);
    final continueButton = find.widgetWithText(ElevatedButton, 'Continue');

    // Button should be disabled initially
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

    // Tap the checkbox to agree
    await tester.tap(checkbox);
    await tester.pump();

    // Button should now be enabled
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);

    // Tap the button and verify navigation to login page
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Login / Create Account'), findsOneWidget);
  });
}
