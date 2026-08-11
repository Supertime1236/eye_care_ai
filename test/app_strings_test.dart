import 'package:flutter_test/flutter_test.dart';
import 'package:eye_care_ai/models/app_strings.dart';

void main() {
  group('AppStrings', () {
    test('vi strings are non-empty for core keys', () {
      const strings = AppStrings(true);
      expect(strings.home, isNotEmpty);
      expect(strings.checkForUpdate, isNotEmpty);
      expect(strings.noUpdateAvailable, isNotEmpty);
      expect(strings.signOut, isNotEmpty);
    });

    test('en strings are non-empty for core keys', () {
      const strings = AppStrings(false);
      expect(strings.home, isNotEmpty);
      expect(strings.checkForUpdate, isNotEmpty);
      expect(strings.noUpdateAvailable, isNotEmpty);
      expect(strings.signOut, isNotEmpty);
    });

    test('vi and en return different localized strings', () {
      const vi = AppStrings(true);
      const en = AppStrings(false);
      expect(vi.checkForUpdate, isNot(equals(en.checkForUpdate)));
    });
  });
}
