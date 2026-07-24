import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/app_state.dart';
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

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

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
    final strings = context.watch<AppState>().strings;
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
                    onTap: () => setState(() => _currentIndex = index),
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
