import 'package:flutter/foundation.dart';
import '../models/app_usage.dart';
import '../services/usage_service.dart';

class UsageProvider extends ChangeNotifier {
  
  
  List<AppUsage> _todayUsages = [];
  Map<String, List<AppUsage>> _weeklyUsages = {};
  bool _isLoading = false;
  String? _error;

  List<AppUsage> get todayUsages => _todayUsages;
  Map<String, List<AppUsage>> get weeklyUsages => _weeklyUsages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Tổng thời gian sử dụng hôm nay
  Duration get totalTodayTime {
    return _todayUsages.fold(
      Duration.zero,
      (sum, usage) => sum + usage.totalTime,
    );
  }

  // Lấy top N ứng dụng sử dụng nhiều nhất
  List<AppUsage> getTopApps(int count) {
    final sorted = List<AppUsage>.from(_todayUsages)
      ..sort((a, b) => b.totalTime.compareTo(a.totalTime));
    return sorted.take(count).toList();
  }

  // Load dữ liệu hôm nay
  Future<void> loadTodayUsage() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _todayUsages = await UsageService.getTodayUsage();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load dữ liệu tuần
  Future<void> loadWeeklyUsage() async {
    try {
      _weeklyUsages = await UsageService.getWeeklyUsage();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading weekly usage: $e');
    }
  }


  // Xóa dữ liệu cache
  void clearCache() {
    _todayUsages = [];
    _weeklyUsages = {};
    notifyListeners();
  }
}