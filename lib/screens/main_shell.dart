import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/rank_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // Trước đây Phone Usage/App Usage chỉ tải MỘT LẦN lúc mở app
  // (refreshHabitsFromDevice() gọi đúng 1 lần trong initState) — số liệu sau
  // đó đứng yên dù người dùng vẫn đang dùng máy. Thêm timer định kỳ để số
  // liệu tự cập nhật trong lúc app đang mở, giống Digital Wellbeing.
  Timer? _usagePollTimer;

  // Mốc thời gian app bị đưa xuống nền — dùng cho chế độ nghỉ mắt THỤ ĐỘNG:
  // nếu người dùng khoá màn hình/rời app đủ lâu rồi quay lại, coi như đã có
  // 1 lần nghỉ mắt (xem didChangeAppLifecycleState bên dưới).
  DateTime? _pausedAt;
  static const _autoBreakMinGap = Duration(seconds: 20);
  // Giới hạn trên để tránh tính bậy: rời máy hàng giờ (đi ngủ, họp dài...)
  // không phải là "nghỉ mắt" theo quy tắc 20-20-20, nên chỉ tính khoảng nghỉ
  // hợp lý trong khung này.
  static const _autoBreakMaxGap = Duration(minutes: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final habit = context.read<HabitProvider>();
    habit.startHabitTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHabitsAndSyncRank();
      _checkForAppUpdate();
    });
    _usagePollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshHabitsAndSyncRank();
    });
  }

  // Mở app lên là tự hỏi GitHub Releases xem có bản mới hơn không (xem
  // lib/services/update_service.dart) — chỉ hỏi 1 LẦN mỗi lần mở app (không
  // đặt trong Timer.periodic như refresh habit ở trên), tránh phiền người
  // dùng bằng dialog bật lên lặp lại giữa lúc họ đang dùng app.
  Future<void> _checkForAppUpdate({bool manual = false, BuildContext? context}) async {
    final update = await UpdateService.instance.checkForUpdate();
    final target = context ?? this.context;
    if (!manual) {
      if (update == null || !mounted) return;
      final strings = target.read<LanguageProvider>().strings;
      if (!mounted) return;
      UpdateDialog.show(target, update, strings);
      return;
    }

    if (!mounted) return;
    final strings = target.read<LanguageProvider>().strings;
    if (update == null) {
      ScaffoldMessenger.of(target).showSnackBar(
        SnackBar(content: Text(strings.updateCheckFailed)),
      );
      return;
    }
    UpdateDialog.show(target, update, strings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed && mounted) {
      // Mở app trở lại (từ nền) -> làm mới ngay, không chờ tick 60s tiếp
      // theo, vì người dùng vừa dùng các app khác trong lúc app này ở nền.
      _refreshHabitsAndSyncRank();

      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final gap = DateTime.now().difference(pausedAt);
      final reminder = context.read<ReminderProvider>();
      if (reminder.autoDetectEyeBreaks && gap >= _autoBreakMinGap && gap <= _autoBreakMaxGap) {
        context.read<HabitProvider>().recordEyeBreak();
      }
    }
  }

  // Làm mới dữ liệu thói quen từ thiết bị RỒI đồng bộ streak mới nhất lên
  // bậc xếp hạng (RankProvider) + Firestore — gộp 2 bước lại một chỗ vì mọi
  // nơi refresh habit đều cần rank cập nhật theo, tránh quên đồng bộ ở một
  // trong các điểm gọi (initState, poll timer, resume từ nền).
  Future<void> _refreshHabitsAndSyncRank() async {
    final habit = context.read<HabitProvider>();
    await habit.refreshHabitsFromDevice();
    if (!mounted) return;
    context.read<RankProvider>().updateStreak(habit.streakDays);
  }

  @override
  void dispose() {
    _usagePollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const SafeArea(
        child: HomeScreen(),
      ),
    );
  }
}