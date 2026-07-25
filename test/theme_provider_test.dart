import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('toggles dark mode and notifies listeners', () async {
      final provider = ThemeProvider();
      await Future<void>.delayed(Duration.zero);
      var notified = 0;
      provider.addListener(() => notified++);

      expect(provider.isDarkMode, isFalse);

      await provider.toggleDarkMode(true);

      expect(provider.isDarkMode, isTrue);
      expect(provider.themeMode, ThemeMode.dark);
      expect(notified, 1);
    });
  });
}
