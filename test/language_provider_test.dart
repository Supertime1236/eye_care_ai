import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/providers/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with default locale vi', () {
      final provider = LanguageProvider();
      expect(provider.locale, const Locale('vi'));
    });

    test('changes locale and persists', () async {
      final provider = LanguageProvider();
      await Future<void>.delayed(Duration.zero);

      await provider.setLocale(const Locale('en'));

      expect(provider.locale, const Locale('en'));

      final fresh = LanguageProvider();
      await Future<void>.delayed(Duration.zero);
      expect(fresh.locale, const Locale('en'));
    });

    test('has vi and en locales', () {
      final provider = LanguageProvider();
      expect(provider.supportedLocales.length, 2);
      expect(provider.supportedLocales, contains(const Locale('vi')));
      expect(provider.supportedLocales, contains(const Locale('en')));
    });
  });
}
