import 'package:flutter_test/flutter_test.dart';

import 'package:reduce_smoking_app/main.dart';

void main() {
  testWidgets('Displays welcome text', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome'), findsOneWidget);
  });
}
