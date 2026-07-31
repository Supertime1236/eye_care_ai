import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/device_data_service.dart';
import '../services/notification_service.dart';

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
  double target;
  double current;
  final int color;
  bool isLive;

  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
}

class HabitProvider extends ChangeNotifier {
  static const _kHasCustomTargetsKey = 'pref_has_custom_habit_targets';
  static const _kHabitTargetPrefix = 'pref_habit_target_';
  static const _kManualSleepHoursKey = 'pref_manual_sleep_hours';
  static const _kManualSleepDateKey = 'pref_manual_sleep_date';

  HabitProvider() {
    ready = _loadSavedPreferences();
  }

  // Awaiting này đảm bảo dữ liệu target đã lưu (nếu có) được nạp XONG trước
  // khi bất kỳ màn hình nào (đặc biệt là khảo sát bắt buộc lần đầu) đọc hoặc
  // ghi vào `habits` — tránh trường hợp việc nạp dữ liệu bất đồng bộ hoàn tất
  // SAU khi khảo sát đã áp dụng kết quả mới, vô tình ghi đè ngược lại giá trị
  // cũ/mặc định (đây là nguyên nhân gây ra lỗi "Outdoor Time luôn hiện 90
  // phút" dù người dùng chọn khác trong khảo sát).
  late final Future<void> ready;

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
      subtitle: 'Health Connect or manual entry',
      icon: '😴',
      unit: 'hrs',
      target: 9,
      color: 0xFF6366F1,
    ),
    HabitData(
      id: 'outdoor',
      title: 'Outdoor Time',
      subtitle: 'GPS location',
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
  int habitsCompletionPercent = 0;
  int eyeBreaksTakenToday = 0;
  int statsTabIndex = 0;
  int statsMetricIndex = 0;
  int streakDays = 0;
  bool hasCustomHabitTargets = false;
  bool surveyCompleted = false;

  // Danh sách dùng chung cho Trang chủ + Thống kê — CHỈ fetch 1 lần mỗi khi
  // refreshHabitsFromDevice() chạy, để 2 màn hình luôn hiện CÙNG MỘT con số
  // (trước đây Thống kê tự fetch riêng, dễ lệch với Trang chủ do khác thời
  // điểm truy vấn).
  List<AppUsageBreakdownEntry> appUsageBreakdown = [];

  int get eyeHealthScore => habitsCompletionPercent;
  double get screenTimeHours => habits.firstWhere((h) => h.id == 'phone').current;
  double get outdoorHours => habits.firstWhere((h) => h.id == 'outdoor').current / 60;
  int get breakCount => habits.firstWhere((h) => h.id == 'breaks').current.round();

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    hasCustomHabitTargets = prefs.getBool(_kHasCustomTargetsKey) ?? hasCustomHabitTargets;

    for (final habit in habits) {
      final key = '$_kHabitTargetPrefix${habit.id}';
      if (prefs.containsKey(key)) {
        habit.target = prefs.getDouble(key) ?? habit.target;
      }
    }

    notifyListeners();
  }

  Future<void> _saveHabitTarget(String habitId, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_habitTargetKey(habitId), value);
  }

  String _habitTargetKey(String habitId) => '$_kHabitTargetPrefix$habitId';

  Future<void> _saveHasCustomHabitTargets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasCustomTargetsKey, true);
  }

  void startHabitTracking() {
    final service = DeviceDataService.instance;
    service.startReadingTracking();
    service.startOutdoorTracking();
    // Cảnh báo dùng điện thoại trong bóng tối: gửi thông báo hệ thống khi
    // môi trường xung quanh tối liên tục quá lâu trong lúc app đang mở.
    service.startDarkRoomMonitoring(() async {
      await NotificationService.instance.showInstantNotification(
        title: '🌙 Bạn đang dùng điện thoại trong bóng tối',
        body: 'Ánh sáng yếu khiến mắt phải điều tiết nhiều hơn, dễ gây mỏi mắt. '
            'Hãy bật đèn hoặc giảm độ sáng màn hình cho phù hợp.',
      );
    });
  }

  Future<void> refreshHabitsFromDevice() async {
    isRefreshingHabits = true;
    notifyListeners();

    final service = DeviceDataService.instance;
    // Mỗi nguồn dữ liệu có timeout RIÊNG (không dùng chung Future.wait không
    // giới hạn thời gian) — nếu một nguồn bị treo (ví dụ hộp thoại xin quyền
    // sức khỏe/GPS chưa được người dùng phản hồi), nó sẽ tự trả về null sau
    // vài giây thay vì làm toàn bộ refresh không bao giờ hoàn tất. Đây chính
    // là lý do trước đây trang chủ đôi khi mãi hiện 0 cho tới khi người dùng
    // chuyển sang tab khác rồi quay lại (lúc đó refresh mới có cơ hội chạy
    // lại và may mắn không bị treo).
    //
    // QUAN TRỌNG: getAppUsageBreakdownToday() chỉ gọi Ở ĐÂY, MỘT LẦN DUY
    // NHẤT — Trang chủ và Thống kê đều đọc lại cùng kết quả này (appUsageBreakdown)
    // thay vì mỗi màn hình tự query native riêng, vốn là lý do 2 nơi từng
    // hiện số giờ khác nhau (query ở 2 thời điểm khác nhau).
    final results = await Future.wait([
      service.getReadingMinutesToday().timeout(const Duration(seconds: 6), onTimeout: () => 0),
      service.getAppUsageBreakdownToday().timeout(const Duration(seconds: 6), onTimeout: () => <AppUsageBreakdownEntry>[]),
      service.getSleepHours().timeout(const Duration(seconds: 6), onTimeout: () => null),
      service.getOutdoorMinutesToday().timeout(const Duration(seconds: 6), onTimeout: () => 0),
      service.getEyeBreaksToday().timeout(const Duration(seconds: 6), onTimeout: () => 0),
    ]);

    appUsageBreakdown = results[1] as List<AppUsageBreakdownEntry>;
    final totalUsageSeconds = appUsageBreakdown.fold<int>(0, (sum, e) => sum + e.usage.inSeconds);
    final phoneHours = appUsageBreakdown.isEmpty ? null : totalUsageSeconds / 3600.0;

    _applyHabitValue('reading', results[0] as double?);
    _applyHabitValue('phone', phoneHours);
    // Health Connect chỉ ĐỌC được dữ liệu ngủ nếu có app khác (Samsung
    // Health, Google Fit, Fitbit...) đã ghi vào đó — nếu máy không cài Health
    // Connect hoặc chưa có app nào ghi dữ liệu ngủ, kết quả sẽ luôn là null
    // (không phải lỗi, chỉ đơn giản là KHÔNG CÓ NGUỒN). Dùng số giờ ngủ nhập
    // tay hôm nay (nếu có) làm phương án dự phòng để habit này luôn dùng
    // được thay vì mãi hiện "Chưa có nguồn dữ liệu".
    double? sleepValue = results[2] as double?;
    sleepValue ??= await _getManualSleepHoursToday();
    _applyHabitValue('sleep', sleepValue);
    _applyHabitValue('outdoor', results[3] as double?);
    final breaks = results[4] as int;
    _applyHabitValue('breaks', breaks.toDouble());
    eyeBreaksTakenToday = breaks;

    _updateHabitsCompletion();
    habitsLastUpdated = DateTime.now();
    isRefreshingHabits = false;

    // Lưu snapshot thật của hôm nay + tính lại streak thật (thay cho số liệu
    // giả cố định trước đây).
    await service.saveDailySnapshot(
      score: habitsCompletionPercent,
      screenHours: screenTimeHours,
      sleepHours: habits.firstWhere((h) => h.id == 'sleep').current,
    );
    streakDays = await service.calculateStreakDays();

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

  void _updateHabitsCompletion() {
    final total = habits.fold<double>(0, (sum, h) => sum + h.progress);
    habitsCompletionPercent = ((total / habits.length) * 100).round();
  }

  Future<double?> _getManualSleepHoursToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_kManualSleepDateKey);
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    if (savedDate != todayKey) return null;
    return prefs.getDouble(_kManualSleepHoursKey);
  }

  // Cho phép người dùng tự nhập số giờ ngủ đêm qua khi Health Connect không
  // có dữ liệu (chưa cài app, hoặc chưa có app nào ghi dữ liệu ngủ vào đó).
  // Giá trị chỉ áp dụng cho hôm nay, ngày mai sẽ tự làm mới.
  Future<void> setManualSleepHours(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    await prefs.setDouble(_kManualSleepHoursKey, hours);
    await prefs.setString(_kManualSleepDateKey, todayKey);

    _applyHabitValue('sleep', hours);
    _updateHabitsCompletion();
    notifyListeners();
  }

  Future<void> recordEyeBreak() async {
    final total = await DeviceDataService.instance.recordEyeBreak();
    eyeBreaksTakenToday = total;
    final habit = habits.firstWhere((h) => h.id == 'breaks');
    habit.current = total.toDouble();
    habit.isLive = true;
    _updateHabitsCompletion();
    notifyListeners();
  }

  void setStatsTabIndex(int index) {
    statsTabIndex = index;
    notifyListeners();
  }

  void setStatsMetricIndex(int index) {
    statsMetricIndex = index;
    notifyListeners();
  }

  Future<void> markSurveyCompleted() async {
    surveyCompleted = true;
    await DeviceDataService.instance.setSurveyCompleted(true);
    notifyListeners();
  }

  void setSurveyCompleted(bool value) {
    surveyCompleted = value;
    notifyListeners();
  }

  Future<void> setHabitTarget(String habitId, double value) async {
    final index = habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    habits[index].target = value;
    await _saveHabitTarget(habitId, value);
    hasCustomHabitTargets = true;
    await _saveHasCustomHabitTargets();
    _updateHabitsCompletion();
    notifyListeners();
  }

  Future<void> applySurveyTargets(Map<String, double> targets) async {
    for (final entry in targets.entries) {
      final index = habits.indexWhere((h) => h.id == entry.key);
      if (index == -1) continue;
      habits[index].target = entry.value;
      await _saveHabitTarget(habits[index].id, entry.value);
    }
    hasCustomHabitTargets = true;
    await _saveHasCustomHabitTargets();
    _updateHabitsCompletion();
    notifyListeners();
  }
}
