import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/providers/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with default locale en', () {
      final provider = LanguageProvider();
      expect(provider.locale, const Locale('en'));
      expect(provider.isVietnamese, isFalse);
    });

    test('toggles locale to vi and persists', () async {
      final provider = LanguageProvider();
      await Future<void>.delayed(Duration.zero);

      await provider.toggleVietnamese(true);

      expect(provider.isVietnamese, isTrue);
      expect(provider.locale, const Locale('vi'));

      final fresh = LanguageProvider();
      await Future<void>.delayed(Duration.zero);
      expect(fresh.isVietnamese, isTrue);
      expect(fresh.locale, const Locale('vi'));
    });

    test('strings reflect locale', () {
      final en = LanguageProvider();
      expect(en.strings.home, 'Home');

      final vi = LanguageProvider()..toggleVietnamese(true);
      expect(vi.strings.home, 'Trang chủ');
    });
  });
}
