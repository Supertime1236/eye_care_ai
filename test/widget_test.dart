import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eye_care_ai/main.dart';
import 'package:eye_care_ai/providers/app_state.dart';

void main() {
  testWidgets('EyeCare app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const EyeCareApp(),
      ),
    );

    expect(find.text('EyeCare AI'), findsOneWidget);
  });
}
