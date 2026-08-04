import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider eye-care settings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('stores and reads eye-care preference values', () async {
      final provider = SettingsProvider();
      await Future<void>.delayed(Duration.zero);

      await provider.setVisionProfile('contact_lens');
      await provider.setReminderStyle('strict');
      await provider.setViewingDistanceMode('manual');
      await provider.setGuardianEmail('guardian@example.com');

      expect(provider.visionProfile, 'contact_lens');
      expect(provider.reminderStyle, 'strict');
      expect(provider.viewingDistanceMode, 'manual');
      expect(provider.guardianEmail, 'guardian@example.com');
    });
  });
}
