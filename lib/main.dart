import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/habits_survey_screen.dart';
import 'screens/main_shell.dart';
import 'services/device_data_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const EyeCareApp(),
    ),
  );
}

class EyeCareApp extends StatelessWidget {
  const EyeCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return MaterialApp(
      title: 'EyeCare AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
          context.read<AppState>().surveyCompleted = true;
          return const MainShell();
        }
        return const HabitsSurveyScreen(mandatory: true);
      },
    );
  }
}
