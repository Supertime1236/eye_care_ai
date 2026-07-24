import 'package:flutter/foundation.dart';

import '../models/app_strings.dart';
import '../services/device_data_service.dart';

// HabitData mô tả một thói quen được theo dõi trong ứng dụng.
// Khác với trước đây, giá trị `current` KHÔNG còn do người dùng tự nhập tay —
// nó được đọc từ cảm biến/hệ điều hành của điện thoại qua DeviceDataService.
// Mỗi thói quen có:
// - id nội bộ để phân biệt
// - title hiển thị trên màn hình
// - subtitle mô tả nguồn dữ liệu thật (vd: "Screen-on time (OS)")
// - icon biểu tượng cảm xúc
// - unit đơn vị đo
// - target mục tiêu cần đạt
// - current giá trị hiện tại (đọc từ thiết bị)
// - color màu hiển thị của thói quen
// - isLive: true nếu đang thực sự lấy được dữ liệu từ thiết bị,
//   false nếu nguồn dữ liệu chưa khả dụng (chưa cấp quyền / nền tảng không hỗ trợ)
class HabitData {
  HabitData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unit,
    required this.target,
    this.current = 0,
    required this.color,
    this.isLive = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String unit;
  final double target;
  double current;
  final int color;
  bool isLive;

  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
}

class AppState extends ChangeNotifier {
  // AppState lưu trữ toàn bộ trạng thái của ứng dụng.
  // Đây là nơi quản lý cài đặt, dữ liệu thói quen, tiến trình kiểm tra mắt, và các chỉ số thống kê.
  // Khi giá trị thay đổi, notifyListeners() sẽ báo cho các widget đang lắng nghe tự cập nhật.
  // Các cài đặt người dùng có thể điều chỉnh.
  // Những giá trị này thay đổi giao diện và ngôn ngữ của ứng dụng.
  bool isDarkMode = false;
  bool useMetric = true;
  bool is24Hour = false;
  bool isVietnamese = false;
  bool notifyBreaks = true;
  bool notifyTests = true;
  bool notifyHabits = true;
  bool notifyTips = true;
  int reminderMinutes = 20;

  int eyeHealthScore = 84;
  double screenTimeHours = 4.2;
  double outdoorHours = 1.5;
  int breakCount = 6;

  // Trạng thái cho màn hình nhắc nghỉ mắt (thay thế Eye Test cũ).
  bool isEyeBreakReminderActive = false;
  int eyeBreaksTakenToday = 0;

  int habitsCompletionPercent = 0;

  final List<HabitData> habits = [
    HabitData(
      id: 'reading',
      title: 'Reading Time',
      subtitle: 'Ambient light & accelerometer',
      icon: '📖',
      unit: 'min',
      target: 60,
      color: 0xFF3B82F6,
    ),
    HabitData(
      id: 'phone',
      title: 'Phone Usage',
      subtitle: 'Screen-on time (OS)',
      icon: '📱',
      unit: 'hrs',
      target: 6,
      color: 0xFF8B5CF6,
    ),
    HabitData(
      id: 'sleep',
      title: 'Sleep',
      subtitle: 'Last night — accelerometer',
      icon: '😴',
      unit: 'hrs',
      target: 9,
      color: 0xFF6366F1,
    ),
    HabitData(
      id: 'outdoor',
      title: 'Outdoor Time',
      subtitle: 'GPS & UV sensor',
      icon: '🌿',
      unit: 'min',
      target: 90,
      color: 0xFF14B8A6,
    ),
    HabitData(
      id: 'breaks',
      title: 'Eye Breaks',
      subtitle: 'Front camera gaze detection',
      icon: '👁️',
      unit: 'breaks',
      target: 12,
      color: 0xFFF97316,
    ),
  ];

  bool isRefreshingHabits = false;
  DateTime? habitsLastUpdated;

  int statsTabIndex = 0;
  int statsMetricIndex = 0;
  int streakDays = 12;

  // Chuyển tab trong màn hình thống kê.
  void setStatsTabIndex(int index) {
    statsTabIndex = index;
    notifyListeners();
  }

  // Chuyển chỉ số đang hiển thị trong biểu đồ.
  void setStatsMetricIndex(int index) {
    statsMetricIndex = index;
    notifyListeners();
  }

  // Các hàm này thực hiện cập nhật cài đặt và thông báo lại cho widget.
  void toggleDarkMode(bool value) {
    isDarkMode = value;
    notifyListeners();
  }

  void toggleMetric(bool value) {
    useMetric = value;
    notifyListeners();
  }

  void toggleTimeFormat(bool value) {
    is24Hour = value;
    notifyListeners();
  }

  void toggleVietnamese(bool value) {
    isVietnamese = value;
    notifyListeners();
  }

  // Bắt đầu các nguồn theo dõi chạy nền trong khi app đang mở (gia tốc kế,
  // GPS định kỳ). Gọi một lần khi app khởi động.
  void startHabitTracking() {
    final service = DeviceDataService.instance;
    service.startReadingTracking();
    service.startOutdoorTracking();
  }

  // Đọc lại dữ liệu thật từ thiết bị cho từng thói quen và cập nhật UI.
  // Habit nào chưa có nguồn dữ liệu khả dụng (chưa cấp quyền / nền tảng
  // không hỗ trợ) sẽ giữ isLive = false thay vì hiện số giả.
  Future<void> refreshHabitsFromDevice() async {
    isRefreshingHabits = true;
    notifyListeners();

    final service = DeviceDataService.instance;

    final results = await Future.wait([
      service.getReadingMinutesToday(),
      service.getPhoneUsageHours(),
      service.getSleepHours(),
      service.getOutdoorMinutesToday(),
      service.getEyeBreaksToday(),
    ]);

    _applyHabitValue('reading', results[0] as double?);
    _applyHabitValue('phone', results[1] as double?);
    _applyHabitValue('sleep', results[2] as double?);
    _applyHabitValue('outdoor', results[3] as double?);
    final breaks = results[4] as int;
    _applyHabitValue('breaks', breaks.toDouble());
    eyeBreaksTakenToday = breaks;

    _updateHabitsCompletion();
    habitsLastUpdated = DateTime.now();
    isRefreshingHabits = false;
    notifyListeners();
  }

  void _applyHabitValue(String id, double? value) {
    final habit = habits.firstWhere((h) => h.id == id);
    if (value == null) {
      habit.isLive = false;
      return;
    }
    habit.current = value.clamp(0, habit.target * 2);
    habit.isLive = true;
  }

  // Cập nhật thời gian nhắc nhở và trạng thái thông báo.
  void setReminderMinutes(int minutes) {
    reminderMinutes = minutes;
    notifyListeners();
  }

  // Dùng một hàm để xử lý nhiều loại thông báo khác nhau.
  void setNotification(String key, bool value) {
    switch (key) {
      case 'breaks':
        notifyBreaks = value;
        break;
      case 'tests':
        notifyTests = value;
        break;
      case 'habits':
        notifyHabits = value;
        break;
      case 'tips':
        notifyTips = value;
        break;
    }
    notifyListeners();
  }

  void _updateHabitsCompletion() {
    final total = habits.fold<double>(
      0,
      (sum, h) => sum + h.progress,
    );
    habitsCompletionPercent = ((total / habits.length) * 100).round();
  }

  void toggleEyeBreakReminder(bool active) {
    isEyeBreakReminderActive = active;
    notifyListeners();
  }
  // Ghi nhận một lần nghỉ mắt thật (người dùng tự xác nhận sau khi nhìn xa
  // theo nhắc nhở). Cộng dồn vào DeviceDataService (lưu theo ngày) và đồng bộ
  // luôn vào habit "Eye Breaks" trên trang Habits.
  Future<void> recordEyeBreak() async {
    final total = await DeviceDataService.instance.recordEyeBreak();
    eyeBreaksTakenToday = total;
    final habit = habits.firstWhere((h) => h.id == 'breaks');
    habit.current = total.toDouble();
    habit.isLive = true;
    _updateHabitsCompletion();
    notifyListeners();
  }

  bool hasCustomHabitTargets = false;

  // Áp dụng các target cá nhân hoá được tính từ bài khảo sát sức khỏe mắt
  // (xem lib/models/eye_health_standards.dart) vào các habit tương ứng.
  void applySurveyTargets(Map<String, double> targets) {
    for (final entry in targets.entries) {
      final index = habits.indexWhere((h) => h.id == entry.key);
      if (index == -1) continue;
      habits[index] = HabitData(
        id: habits[index].id,
        title: habits[index].title,
        subtitle: habits[index].subtitle,
        icon: habits[index].icon,
        unit: habits[index].unit,
        target: entry.value,
        current: habits[index].current,
        color: habits[index].color,
        isLive: habits[index].isLive,
      );
    }
    hasCustomHabitTargets = true;
    _updateHabitsCompletion();
    notifyListeners();
  }

  AppStrings get strings => AppStrings(isVietnamese);
}
