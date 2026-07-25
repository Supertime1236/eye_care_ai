import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eye_care_ai/main.dart';
import 'package:eye_care_ai/providers/theme_provider.dart';

void main() {
  testWidgets('EyeCare app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const EyeCareApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
