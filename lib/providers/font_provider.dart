import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Danh sách font người dùng có thể chọn để làm giao diện đa dạng hơn.
//
// QUAN TRỌNG VỀ TIẾNG VIỆT: KHÔNG áp dụng lựa chọn font này khi ngôn ngữ
// đang là Tiếng Việt — luôn ép dùng "Be Vietnam Pro" (xem getTextTheme bên
// dưới), vì đây là font đã được kiểm chứng hiển thị ĐÚNG độ đậm (font-weight)
// cho dấu thanh/dấu phụ tiếng Việt (xem ghi chú lịch sử: trước đây dùng font
// hệ thống mặc định khiến dấu tiếng Việt hiển thị sai độ đậm do font
// fallback). Các font khác trong danh sách này TUY vẫn có bộ ký tự Latin mở
// rộng nhưng chưa được kiểm chứng kỹ với dấu tiếng Việt, nên chỉ bật cho chế
// độ Tiếng Anh để "tránh lỗi phông" như yêu cầu.
enum AppFontChoice { beVietnamPro, nunito, quicksand, inter, poppins }

extension AppFontChoiceX on AppFontChoice {
  String label(bool vi) {
    switch (this) {
      case AppFontChoice.beVietnamPro:
        return 'Be Vietnam Pro';
      case AppFontChoice.nunito:
        return 'Nunito';
      case AppFontChoice.quicksand:
        return 'Quicksand';
      case AppFontChoice.inter:
        return 'Inter';
      case AppFontChoice.poppins:
        return 'Poppins';
    }
  }

  // Chữ mẫu ngắn hiển thị ngay trong danh sách chọn font để người dùng thấy
  // trước hình dạng font mà không cần áp dụng thử.
  String get previewText => 'Aa Bb 123';
}

class FontProvider extends ChangeNotifier {
  static const _kFontPrefKey = 'pref_app_font_choice';

  FontProvider() {
    _loadSavedPreference();
  }

  AppFontChoice _choice = AppFontChoice.beVietnamPro;
  AppFontChoice get choice => _choice;

  Future<void> _loadSavedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kFontPrefKey);
    if (saved != null) {
      _choice = AppFontChoice.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppFontChoice.beVietnamPro,
      );
      notifyListeners();
    }
  }

  Future<void> setChoice(AppFontChoice value) async {
    _choice = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontPrefKey, value.name);
    notifyListeners();
  }

  // Trả về TextTheme phù hợp: TIẾNG VIỆT luôn dùng Be Vietnam Pro bất kể lựa
  // chọn của người dùng là gì (an toàn dấu tiếng Việt); các ngôn ngữ khác
  // mới áp dụng đúng font đã chọn.
  TextTheme getTextTheme(bool isVietnamese) {
    final effective = isVietnamese ? AppFontChoice.beVietnamPro : _choice;
    switch (effective) {
      case AppFontChoice.beVietnamPro:
        return GoogleFonts.beVietnamProTextTheme();
      case AppFontChoice.nunito:
        return GoogleFonts.nunitoTextTheme();
      case AppFontChoice.quicksand:
        return GoogleFonts.quicksandTextTheme();
      case AppFontChoice.inter:
        return GoogleFonts.interTextTheme();
      case AppFontChoice.poppins:
        return GoogleFonts.poppinsTextTheme();
    }
  }

  TextStyle getAppBarTitleStyle(bool isVietnamese, {required Color color}) {
    final effective = isVietnamese ? AppFontChoice.beVietnamPro : _choice;
    final base = switch (effective) {
      AppFontChoice.beVietnamPro => GoogleFonts.beVietnamPro,
      AppFontChoice.nunito => GoogleFonts.nunito,
      AppFontChoice.quicksand => GoogleFonts.quicksand,
      AppFontChoice.inter => GoogleFonts.inter,
      AppFontChoice.poppins => GoogleFonts.poppins,
    };
    return base(fontSize: 18, fontWeight: FontWeight.w700, color: color);
  }
}
