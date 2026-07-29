import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';
import 'eye_break_screen.dart';
import 'habits_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
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

  static const _screens = [
    HomeScreen(),
    EyeBreakScreen(),
    HabitsScreen(),
    StatisticsScreen(),
    ChatScreen(),
    SettingsScreen(),
  ];

  List<_NavItem> _buildNavItems(AppStrings strings) => [
        _NavItem(icon: Icons.home_rounded, label: strings.home, color: AppColors.homeAccent),
        _NavItem(icon: Icons.visibility_rounded, label: strings.eyeTest, color: AppColors.testAccent),
        _NavItem(icon: Icons.check_circle_outline, label: strings.habits, color: AppColors.habitsAccent),
        _NavItem(icon: Icons.bar_chart_rounded, label: strings.stats, color: AppColors.statsAccent),
        _NavItem(icon: Icons.chat_bubble_outline, label: strings.chat, color: AppColors.chatAccent),
        _NavItem(icon: Icons.settings_outlined, label: strings.settings, color: AppColors.settingsAccent),
      ];

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final navItems = _buildNavItems(strings);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(child: _screens[_currentIndex]),
      bottomNavigationBar: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkBorder
                    : AppColors.border,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final selected = _currentIndex == index;
                  return _NavButton(
                    item: item,
                    selected: selected,
                    onTap: () {
                      setState(() => _currentIndex = index);
                      // Vào lại Trang chủ/Thói quen/Thống kê -> làm mới ngay
                      // để không phải chờ chu kỳ 60s.
                      if (index == 0 || index == 2 || index == 3) {
                        context.read<HabitProvider>().refreshHabitsFromDevice();
                      }
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: selected
                    ? item.color.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: selected ? item.color : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? item.color : AppColors.textMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 9,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
