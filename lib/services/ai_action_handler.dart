import 'dart:convert';

import '../providers/habit_provider.dart';
import 'focus_mode_service.dart';

/// Cho phép AI không chỉ TRẢ LỜI mà còn THAO TÁC được với app.
///
/// Cách hoạt động: system prompt (xem eye_chat_service.dart) dạy cho model
/// một "giao thức" đơn giản — khi muốn thực hiện hành động trong app (ví dụ
/// người dùng nhắn "mắt mình mỏi/đau quá" thì AI có thể tự hạ mục tiêu Phone
/// Usage xuống), model chèn 1 khối JSON được bọc trong %%ACTION%% ... %%END%%
/// ở cuối câu trả lời. Vì đây là model dạng text-completion thuần (không
/// chắc NIM endpoint hỗ trợ "function calling" chuẩn OpenAI khi streaming),
/// dùng 1 giao thức tự định nghĩa bằng text sẽ chắc chắn hoạt động với MỌI
/// model, không phụ thuộc API có hỗ trợ tools hay không.
///
/// Sau khi nhận đủ phản hồi (stream xong), `AiActionHandler.extract()` tách
/// khối JSON đó ra khỏi văn bản hiển thị, rồi `execute()` áp dụng thay đổi
/// thật vào HabitProvider/FocusModeService và trả về câu xác nhận để hiện
/// tiếp cho người dùng thấy app ĐÃ thay đổi thật, không chỉ là lời nói suông.
class AiAction {
  AiAction({required this.type, required this.params});

  final String type;
  final Map<String, dynamic> params;

  factory AiAction.fromJson(Map<String, dynamic> json) {
    return AiAction(
      type: (json['action'] ?? '').toString(),
      params: json,
    );
  }
}

class AiActionResult {
  AiActionResult({required this.cleanedText, required this.actions});

  final String cleanedText;
  final List<AiAction> actions;
}

class AiActionHandler {
  AiActionHandler._();

  static final RegExp _tagPattern = RegExp(
    r'%%ACTION%%\s*(.*?)\s*%%END%%',
    dotAll: true,
  );

  // Giới hạn giá trị hợp lý cho từng loại mục tiêu, để dù model có "sáng
  // tạo" đề xuất số điên rồ (ví dụ 0 giờ ngủ, hoặc 999 giờ dùng điện thoại)
  // thì app cũng không áp dụng bừa — luôn kẹp về khoảng an toàn/thực tế.
  static const Map<String, _Range> _targetRanges = {
    'phone': _Range(min: 1, max: 12), // giờ/ngày
    'sleep': _Range(min: 4, max: 12), // giờ/đêm
    'outdoor': _Range(min: 15, max: 240), // phút/ngày
    'breaks': _Range(min: 1, max: 30), // số lần nghỉ mắt/ngày
  };

  /// Tách các khối %%ACTION%%{...}%%END%% ra khỏi [rawText], trả về text đã
  /// làm sạch (để hiển thị cho người dùng) và danh sách action hợp lệ.
  static AiActionResult extract(String rawText) {
    final actions = <AiAction>[];
    final cleaned = rawText.replaceAllMapped(_tagPattern, (match) {
      final jsonPart = match.group(1) ?? '';
      try {
        final decoded = jsonDecode(jsonPart);
        if (decoded is Map<String, dynamic>) {
          actions.add(AiAction.fromJson(decoded));
        } else if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              actions.add(AiAction.fromJson(item));
            }
          }
        }
      } catch (_) {
        // Model lỡ trả JSON sai định dạng -> bỏ qua action, vẫn giữ phần
        // text còn lại hiển thị bình thường, không làm crash/kẹt chat.
      }
      return '';
    });
    return AiActionResult(cleanedText: cleaned.trim(), actions: actions);
  }

  /// Áp dụng danh sách action vào app thật, trả về các dòng xác nhận
  /// (tiếng Việt hoặc Anh tuỳ [isVietnamese]) để hiện cho người dùng thấy.
  static Future<List<String>> execute(
    List<AiAction> actions, {
    required HabitProvider habits,
    required bool isVietnamese,
  }) async {
    final confirmations = <String>[];
    for (final action in actions) {
      switch (action.type) {
        case 'set_habit_target':
          final confirmation = await _setHabitTarget(action, habits, isVietnamese);
          if (confirmation != null) confirmations.add(confirmation);
          break;
        case 'record_eye_break':
          await habits.recordEyeBreak();
          confirmations.add(isVietnamese
              ? '✅ Đã ghi nhận 1 lần nghỉ mắt cho hôm nay.'
              : '✅ Logged one eye break for today.');
          break;
        case 'enable_focus_mode':
          confirmations.add(await _toggleFocusMode(true, isVietnamese));
          break;
        case 'disable_focus_mode':
          confirmations.add(await _toggleFocusMode(false, isVietnamese));
          break;
        default:
          // Action lạ (model bịa ra loại không có thật) -> lờ đi, không báo lỗi
          // cho người dùng vì đây là lỗi của model, không phải của họ.
          break;
      }
    }
    return confirmations;
  }

  static Future<String?> _setHabitTarget(
    AiAction action,
    HabitProvider habits,
    bool isVietnamese,
  ) async {
    final habitId = (action.params['habit'] ?? '').toString();
    final rawValue = action.params['value'];
    final value = rawValue is num ? rawValue.toDouble() : double.tryParse('$rawValue');
    final range = _targetRanges[habitId];
    if (value == null || range == null) return null;

    final index = habits.habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return null;
    final habit = habits.habits[index];
    if (habit.isComingSoon) return null;

    final oldTarget = habit.target;
    final newTarget = value.clamp(range.min, range.max).toDouble();
    await habits.setHabitTarget(habitId, newTarget);

    final title = _habitLabel(habitId, isVietnamese);
    final unit = _habitUnit(habitId, isVietnamese);
    final oldStr = _formatNumber(oldTarget);
    final newStr = _formatNumber(newTarget);
    final direction = newTarget < oldTarget
        ? (isVietnamese ? 'giảm' : 'lowered')
        : (isVietnamese ? 'tăng' : 'raised');

    return isVietnamese
        ? '🎯 Đã $direction mục tiêu "$title": $oldStr → $newStr $unit/ngày.'
        : '🎯 ${direction[0].toUpperCase()}${direction.substring(1)} "$title" target: $oldStr → $newStr $unit/day.';
  }

  static Future<String> _toggleFocusMode(bool enable, bool isVietnamese) async {
    final service = FocusModeService.instance;
    final hasAccess = await service.hasAccess();
    if (!hasAccess) {
      return isVietnamese
          ? '⚠️ Mình chưa được cấp quyền để bật Chế độ Tập trung. Vào Cài đặt > Chế độ Tập trung để cấp quyền nhé.'
          : '⚠️ I don\'t have permission to toggle Focus Mode yet. Please enable it under Settings > Focus Mode.';
    }
    final success = enable ? await service.enable() : await service.disable();
    if (!success) {
      return isVietnamese ? '⚠️ Không bật/tắt được Chế độ Tập trung.' : '⚠️ Couldn\'t toggle Focus Mode.';
    }
    if (enable) {
      return isVietnamese
          ? '🔕 Đã bật Chế độ Tập trung — thông báo sẽ được chặn để mắt bạn nghỉ ngơi.'
          : '🔕 Focus Mode is on — notifications will be blocked so your eyes can rest.';
    }
    return isVietnamese ? '🔔 Đã tắt Chế độ Tập trung.' : '🔔 Focus Mode is off.';
  }

  static String _habitLabel(String id, bool vi) {
    switch (id) {
      case 'phone':
        return vi ? 'Thời gian dùng điện thoại' : 'Phone Usage';
      case 'sleep':
        return vi ? 'Giấc ngủ' : 'Sleep';
      case 'outdoor':
        return vi ? 'Thời gian ngoài trời' : 'Outdoor Time';
      case 'breaks':
        return vi ? 'Nghỉ mắt' : 'Eye Breaks';
      default:
        return id;
    }
  }

  static String _habitUnit(String id, bool vi) {
    switch (id) {
      case 'phone':
      case 'sleep':
        return vi ? 'giờ' : 'hrs';
      case 'outdoor':
        return vi ? 'phút' : 'min';
      case 'breaks':
        return vi ? 'lần' : 'times';
      default:
        return '';
    }
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

class _Range {
  const _Range({required this.min, required this.max});
  final double min;
  final double max;
}
