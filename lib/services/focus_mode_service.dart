import 'package:flutter/services.dart';

// Chế độ Focus: chặn thông báo app khác trong lúc đang đếm ngược giữa 2 lần
// nghỉ mắt, giảm giật mình/mất tập trung do bị làm phiền liên tục — dùng
// Do Not Disturb của hệ thống (xem FocusModeHandler.kt phía native).
class FocusModeService {
  FocusModeService._();
  static final instance = FocusModeService._();

  static const _channel = MethodChannel('eye_care_ai/focus_mode');

  Future<bool> hasAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    try {
      await _channel.invokeMethod('openAccessSettings');
    } catch (_) {}
  }

  // Trả về false nếu chưa được cấp quyền "Notification policy access" —
  // gọi hasAccess() trước để hiện đúng lời nhắc thay vì âm thầm không làm gì.
  Future<bool> enable() async {
    try {
      return await _channel.invokeMethod<bool>('enable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disable() async {
    try {
      return await _channel.invokeMethod<bool>('disable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isCurrentlyEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }
}