import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EyeCare app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('EyeCare AI'))),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('EyeCare AI'), findsOneWidget);
  });
}
