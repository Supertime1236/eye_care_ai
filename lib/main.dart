import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/accent_color_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/font_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/language_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/settings_more_provider.dart';
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
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => AccentColorProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsMoreProvider()),
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
    final font = context.watch<FontProvider>();
    final accent = context.watch<AccentColorProvider>();
    final isVietnamese = context.watch<LanguageProvider>().isVietnamese;
    final fontTextTheme = font.getTextTheme(isVietnamese);

    return MaterialApp(
      title: 'EyeCare AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentSeed: accent.seedColor, fontTextTheme: fontTextTheme),
      darkTheme: AppTheme.dark(accentSeed: accent.seedColor, fontTextTheme: fontTextTheme),
      themeMode: theme.themeMode,
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  late final Future<bool> _surveyCompletedFuture;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _surveyCompletedFuture = DeviceDataService.instance.isSurveyCompleted();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestDeferredSystemPermissions();
    });
  }

  // BUG ĐÃ SỬA: dùng context.watch<AuthProvider>() bên trong builder của
  // FutureBuilder không đảm bảo rebuild _AppGate mỗi lần AuthProvider đổi
  // trạng thái (đã xác nhận qua debug log: notifyListeners() chạy đúng
  // nhưng widget không build lại) — có thể do context của FutureBuilder
  // không được Provider gắn subscription đúng cách trong 1 số trường hợp.
  // Giải pháp chắc chắn: tự addListener() trực tiếp vào AuthProvider và gọi
  // setState() thủ công, không phụ thuộc vào cơ chế watch/InheritedWidget.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(_authProvider, auth)) {
      _authProvider?.removeListener(_onAuthChanged);
      _authProvider = auth;
      _authProvider!.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<HabitProvider>().setSurveyCompleted(true);
          });
          final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
          debugPrint('🚪 _AppGate build: isLoggedIn=$isLoggedIn');
          return isLoggedIn ? const MainShell() : const LoginScreen();
        }
        return const HabitsSurveyScreen(mandatory: true);
      },
    );
  }
}