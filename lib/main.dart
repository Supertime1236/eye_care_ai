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
import 'providers/rank_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/settings_more_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/consent_screen.dart';
import 'screens/habits_survey_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/analytics_service.dart';
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
        ChangeNotifierProvider(
          create: (_) => SettingsMoreProvider()..init(),
        ),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => RankProvider()),
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

class AppLoadingSkeleton extends StatelessWidget {
  const AppLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE9EEF7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _SkeletonBlock(width: 180, height: 18),
              const SizedBox(height: 24),
              _SkeletonCard(),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Expanded(child: _SkeletonCard(height: 120)),
                  SizedBox(width: 12),
                  Expanded(child: _SkeletonCard(height: 120)),
                  SizedBox(width: 12),
                  Expanded(child: _SkeletonCard(height: 120)),
                ],
              ),
              const SizedBox(height: 20),
              _SkeletonBlock(width: 160, height: 18),
              const SizedBox(height: 12),
              const _SkeletonCard(height: 170),
              const SizedBox(height: 14),
              const _SkeletonCard(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({this.height = 90});
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final highlight = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 120, height: 12, decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 12),
            Container(width: 220, height: 10, decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 8),
            Container(width: 180, height: 10, decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(999))),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
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
  late final Future<bool> _consentGivenFuture;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _surveyCompletedFuture = DeviceDataService.instance.isSurveyCompleted();
    _consentGivenFuture = AnalyticsService.instance.init().then((_) => AnalyticsService.instance.consentGiven);
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
      future: _consentGivenFuture,
      builder: (context, consentSnapshot) {
        if (!consentSnapshot.hasData) {
          return const AppLoadingSkeleton();
        }
        // Consent not given → show consent screen
        if (consentSnapshot.data != true) {
          return const ConsentScreen();
        }
        // Consent given → check survey
        return FutureBuilder<bool>(
          future: _surveyCompletedFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AppLoadingSkeleton();
            }
            if (snapshot.data == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<HabitProvider>().setSurveyCompleted(true);
              });
              final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
              return isLoggedIn ? const MainShell() : const LoginScreen();
            }
            return const HabitsSurveyScreen(mandatory: true);
          },
        );
      },
    );
  }
}