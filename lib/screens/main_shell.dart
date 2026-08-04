import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/reminder_provider.dart';
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
      habit.refreshHabitsFromDevice();
    });
    _usagePollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      context.read<HabitProvider>().refreshHabitsFromDevice();
    });
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
      context.read<HabitProvider>().refreshHabitsFromDevice();

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