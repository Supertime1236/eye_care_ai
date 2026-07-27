import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/language_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/habits_survey_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/device_data_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cần google-services.json (Android) / GoogleService-Info.plist (iOS) đã
  // đặt đúng chỗ — xem hướng dẫn Firebase mình gửi kèm.
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (_) => ProfileProvider(),
          update: (_, auth, profile) => profile!..syncFromUser(auth.user),
        ),
      ],
      child: const EyeCareApp(),
    ),
  );
}

class EyeCareApp extends StatelessWidget {
  const EyeCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'EyeCare AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.themeMode,
      home: const _AppGate(),
    );
  }
}

// _AppGate quyết định màn hình đầu tiên người dùng thấy:
// - Nếu chưa từng hoàn thành khảo sát sức khỏe mắt -> bắt buộc làm khảo sát
//   trước (không cho bỏ qua, xem HabitsSurveyScreen(mandatory: true)).
// - Nếu đã làm rồi -> vào thẳng MainShell như bình thường.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  late final Future<bool> _surveyCompletedFuture;

  @override
  void initState() {
    super.initState();
    _surveyCompletedFuture = DeviceDataService.instance.isSurveyCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _surveyCompletedFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) {
          context.read<HabitProvider>().setSurveyCompleted(true);
          // Sau khảo sát: cần đăng nhập mới vào được app chính.
          final auth = context.watch<AuthProvider>();
          return auth.isLoggedIn ? const MainShell() : const LoginScreen();
        }
        return const HabitsSurveyScreen(mandatory: true);
      },
    );
  }
}
