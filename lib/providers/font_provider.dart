import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Danh sách font người dùng có thể chọn để làm giao diện đa dạng hơn.
//
// QUAN TRỌNG VỀ TIẾNG VIỆT: mỗi font khai báo rõ `supportsVietnamese` — chỉ
// những font đã kiểm chứng có đủ bộ ký tự + đúng độ đậm cho dấu thanh/dấu
// phụ tiếng Việt mới được bật khi ngôn ngữ app là Tiếng Việt (xem
// getTextTheme bên dưới). Nếu người dùng đang chọn 1 font không hỗ trợ tiếng
// Việt rồi đổi ngôn ngữ sang Tiếng Việt, app tự động dùng tạm Be Vietnam Pro
// cho tới khi họ chọn lại — tránh lỗi hiển thị dấu ("lỗi phông").
enum AppFontChoice {
  beVietnamPro,
  mulish,
  lexend,
  montserrat,
  nunito,
  quicksand,
  inter,
  poppins,
}

extension AppFontChoiceX on AppFontChoice {
  String label(bool vi) {
    switch (this) {
      case AppFontChoice.beVietnamPro:
        return 'Be Vietnam Pro';
      case AppFontChoice.mulish:
        return 'Mulish';
      case AppFontChoice.lexend:
        return 'Lexend';
      case AppFontChoice.montserrat:
        return 'Montserrat';
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

  // Font đã kiểm chứng có bộ ký tự Latin Extended đầy đủ + đúng độ đậm cho
  // dấu tiếng Việt -> an toàn để bật khi app đang ở chế độ Tiếng Việt.
  bool get supportsVietnamese {
    switch (this) {
      case AppFontChoice.beVietnamPro:
      case AppFontChoice.mulish:
      case AppFontChoice.lexend:
      case AppFontChoice.montserrat:
        return true;
      case AppFontChoice.nunito:
      case AppFontChoice.quicksand:
      case AppFontChoice.inter:
      case AppFontChoice.poppins:
        return false;
    }
  }

  // Chữ mẫu ngắn hiển thị ngay trong danh sách chọn font để người dùng thấy
  // trước hình dạng font mà không cần áp dụng thử. Với font hỗ trợ tiếng
  // Việt, hiện thêm chữ có dấu để thấy rõ độ đậm dấu render đúng.
  String get previewText => supportsVietnamese ? 'Aa Bb 123 – Tiếng Việt' : 'Aa Bb 123';
}

class FontProvider extends ChangeNotifier {
  static const _kFontPrefKey = 'pref_app_font_choice';

  FontProvider() {
    _loadSavedPreference();
  }

  AppFontChoice _choice = AppFontChoice.beVietnamPro;
  AppFontChoice get choice => _choice;

  // Danh sách font hợp lệ cho ngôn ngữ hiện tại — dùng cho picker UI để chỉ
  // hiện các lựa chọn an toàn thay vì toàn bộ enum.
  List<AppFontChoice> availableFor(bool isVietnamese) {
    if (!isVietnamese) return AppFontChoice.values;
    return AppFontChoice.values.where((f) => f.supportsVietnamese).toList();
  }

  Future<void> reload() => _loadSavedPreference();

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

  // Font thực sự áp dụng cho ngôn ngữ hiện tại: nếu đang ở Tiếng Việt và lựa
  // chọn hiện tại không hỗ trợ tiếng Việt -> tạm dùng Be Vietnam Pro để
  // tránh lỗi hiển thị dấu, thay vì ép người dùng phải tự đổi lại.
  AppFontChoice effectiveChoice(bool isVietnamese) {
    if (isVietnamese && !_choice.supportsVietnamese) return AppFontChoice.beVietnamPro;
    return _choice;
  }

  TextTheme getTextTheme(bool isVietnamese) {
    final effective = effectiveChoice(isVietnamese);
    switch (effective) {
      case AppFontChoice.beVietnamPro:
        return GoogleFonts.beVietnamProTextTheme();
      case AppFontChoice.mulish:
        return GoogleFonts.mulishTextTheme();
      case AppFontChoice.lexend:
        return GoogleFonts.lexendTextTheme();
      case AppFontChoice.montserrat:
        return GoogleFonts.montserratTextTheme();
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
    final effective = effectiveChoice(isVietnamese);
    final base = switch (effective) {
      AppFontChoice.beVietnamPro => GoogleFonts.beVietnamPro,
      AppFontChoice.mulish => GoogleFonts.mulish,
      AppFontChoice.lexend => GoogleFonts.lexend,
      AppFontChoice.montserrat => GoogleFonts.montserrat,
      AppFontChoice.nunito => GoogleFonts.nunito,
      AppFontChoice.quicksand => GoogleFonts.quicksand,
      AppFontChoice.inter => GoogleFonts.inter,
      AppFontChoice.poppins => GoogleFonts.poppins,
    };
    return base(fontSize: 18, fontWeight: FontWeight.w700, color: color);
  }
}
