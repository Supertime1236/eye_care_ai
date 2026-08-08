import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:light/light.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/brightness_service.dart';

// "Tự động điều chỉnh độ sáng": khác với "Gợi ý độ sáng" cũ (chỉ đọc 1 mẫu
// lux rồi gợi ý 1 lần khi người dùng tự mở dialog), tính năng này LẮNG NGHE
// LIÊN TỤC cảm biến ánh sáng môi trường và tự áp độ sáng màn hình tương ứng
// theo thời gian thực — giống Auto-brightness của hệ điều hành nhưng dựa
// trên chính cảm biến app đọc được (một số máy tắt auto-brightness gốc hoặc
// hiệu chỉnh không hợp mắt người dùng).
//
// GIỚI HẠN THỰC TẾ CẦN BIẾT: đổi độ sáng HỆ THỐNG là quyền đặc biệt của
// Android ("Modify system settings" / WRITE_SETTINGS) — không xin được qua
// popup thường, người dùng phải tự bật tay trong Cài đặt hệ thống (xem
// BrightnessService.openSystemSettings()). Nếu chưa cấp quyền, tính năng
// không thể bật (needsPermission = true, UI phải hiện nút "Cấp quyền").
class AutoBrightnessProvider extends ChangeNotifier {
  static const _kEnabledKey = 'pref_auto_brightness_enabled';

  AutoBrightnessProvider() {
    _loadSavedPreference();
  }

  bool _enabled = false;
  bool _needsPermission = false;
  int? _lastLux;
  StreamSubscription<int>? _luxSub;
  DateTime _lastApplied = DateTime.fromMillisecondsSinceEpoch(0);

  bool get enabled => _enabled;
  bool get needsPermission => _needsPermission;
  int? get lastLux => _lastLux;

  Future<void> _loadSavedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final wasEnabled = prefs.getBool(_kEnabledKey) ?? false;
    if (wasEnabled) {
      // Người dùng đã bật từ trước -> thử bật lại luôn khi mở app, miễn là
      // quyền vẫn còn (nếu bị thu hồi quyền entre giữa chừng, setEnabled sẽ
      // tự phát hiện và set needsPermission=true thay vì bật im lặng).
      await setEnabled(true, persist: false);
    }
  }

  Future<void> setEnabled(bool value, {bool persist = true}) async {
    if (!value) {
      _stopListening();
      _enabled = false;
      _needsPermission = false;
      if (persist) await _save(false);
      notifyListeners();
      return;
    }

    final canChange = await BrightnessService.instance.canChangeSystemBrightness();
    if (!canChange) {
      _enabled = false;
      _needsPermission = true;
      if (persist) await _save(false);
      notifyListeners();
      return;
    }

    _needsPermission = false;
    _enabled = true;
    if (persist) await _save(true);
    _startListening();
    notifyListeners();
  }

  Future<void> requestPermission() async {
    await BrightnessService.instance.openSystemSettings();
    // Người dùng bật gạt xong quay lại app -> thử bật lại tính năng luôn,
    // đỡ phải tự bấm công tắc lần 2.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final canChange = await BrightnessService.instance.canChangeSystemBrightness();
    if (canChange) {
      await setEnabled(true);
    }
  }

  void _startListening() {
    _luxSub?.cancel();
    try {
      _luxSub = Light().lightSensorStream.listen(
            _onLuxReading,
            onError: (_) {},
          );
    } catch (_) {
      // Máy không có cảm biến ánh sáng -> tắt tính năng, không lỗi vỡ UI.
      _enabled = false;
      notifyListeners();
    }
  }

  void _stopListening() {
    _luxSub?.cancel();
    _luxSub = null;
  }

  void _onLuxReading(int lux) {
    _lastLux = lux;
    // Throttle: cảm biến ánh sáng bắn sự kiện RẤT nhiều lần/giây, gọi
    // applySystemBrightness() liên tục sẽ giật màn hình + tốn pin vô ích.
    // Chỉ áp lại độ sáng tối đa 1 lần mỗi 1.5 giây.
    final now = DateTime.now();
    if (now.difference(_lastApplied) < const Duration(milliseconds: 1500)) {
      notifyListeners(); // vẫn cập nhật lux hiển thị debug/UI nếu cần
      return;
    }
    _lastApplied = now;
    final target = BrightnessService.instance.suggestBrightnessForLux(lux);
    BrightnessService.instance.applySystemBrightness(target);
    notifyListeners();
  }

  Future<void> _save(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}