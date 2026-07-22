import 'package:flutter/foundation.dart';

import '../models/app_strings.dart';

// HabitData mô tả một thói quen được theo dõi trong ứng dụng.
// Mỗi thói quen có tên, biểu tượng, đơn vị đo, mục tiêu, giá trị hiện tại và màu sắc.
// HabitData là cấu trúc dữ liệu cho một thói quen theo dõi.
// Mỗi thói quen có:
// - id nội bộ để phân biệt
// - title hiển thị trên màn hình
// - icon biểu tượng cảm xúc
// - unit đơn vị đo
// - target mục tiêu cần đạt
// - current giá trị hiện tại
// - color màu hiển thị của thói quen
class HabitData {
  HabitData({
    required this.id,
    required this.title,
    required this.icon,
    required this.unit,
    required this.target,
    required this.current,
    required this.color,
  });

  final String id;
  final String title;
  final String icon;
  final String unit;
  final int target;
  int current;
  final int color;

  double get progress => (current / target).clamp(0.0, 1.0);
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

  int eyeTestStep = 0;
  String? leftEyeResult;
  String? rightEyeResult;
  bool testingLeftEye = true;

  int habitsCompletionPercent = 67;

  final List<HabitData> habits = [
    HabitData(
      id: 'reading',
      title: 'Reading Distance',
      icon: '📖',
      unit: 'cm',
      target: 40,
      current: 35,
      color: 0xFF3B82F6,
    ),
    HabitData(
      id: 'phone',
      title: 'Phone Usage',
      icon: '📱',
      unit: 'hrs',
      target: 3,
      current: 2,
      color: 0xFF8B5CF6,
    ),
    HabitData(
      id: 'sleep',
      title: 'Sleep',
      icon: '😴',
      unit: 'hrs',
      target: 8,
      current: 7,
      color: 0xFF6366F1,
    ),
    HabitData(
      id: 'outdoor',
      title: 'Outdoor Time',
      icon: '🌳',
      unit: 'hrs',
      target: 2,
      current: 1,
      color: 0xFF14B8A6,
    ),
    HabitData(
      id: 'breaks',
      title: 'Eye Breaks',
      icon: '👁️',
      unit: 'times',
      target: 8,
      current: 6,
      color: 0xFFF97316,
    ),
    HabitData(
      id: 'water',
      title: 'Water Intake',
      icon: '💧',
      unit: 'glasses',
      target: 8,
      current: 5,
      color: 0xFF06B6D4,
    ),
  ];

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

  void setHabitCurrent(String id, int value) {
    final habit = habits.firstWhere((h) => h.id == id);
    habit.current = value.clamp(0, habit.target * 2);
    _updateHabitsCompletion();
    notifyListeners();
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

  // Tăng giảm giá trị của thói quen theo id.
  // Giá trị được giới hạn trong khoảng từ 0 đến target * 2.
  void incrementHabit(String id) {
    final habit = habits.firstWhere((h) => h.id == id);
    if (habit.current < habit.target * 2) {
      habit.current++;
      _updateHabitsCompletion();
      notifyListeners();
    }
  }

  void decrementHabit(String id) {
    final habit = habits.firstWhere((h) => h.id == id);
    if (habit.current > 0) {
      habit.current--;
      _updateHabitsCompletion();
      notifyListeners();
    }
  }

  void _updateHabitsCompletion() {
    final total = habits.fold<double>(
      0,
      (sum, h) => sum + h.progress,
    );
    habitsCompletionPercent = ((total / habits.length) * 100).round();
  }

  void nextEyeTestStep() {
    if (eyeTestStep < 3) {
      eyeTestStep++;
      notifyListeners();
    }
  }

  void resetEyeTest() {
    eyeTestStep = 0;
    leftEyeResult = null;
    rightEyeResult = null;
    testingLeftEye = true;
    notifyListeners();
  }

  void submitEyeResult(String result) {
    if (testingLeftEye) {
      leftEyeResult = result;
      testingLeftEye = false;
      eyeTestStep = 1;
    } else {
      rightEyeResult = result;
      eyeTestStep = 3;
    }
    notifyListeners();
  }

  AppStrings get strings => AppStrings(isVietnamese);
}
