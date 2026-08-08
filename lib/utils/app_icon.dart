import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Toàn bộ icon CHỨC NĂNG (menu, nút, thẻ habit, cài đặt, logo màn đăng
// nhập...) trước đây dùng emoji dạng String render qua Text() — nhìn thiếu
// chuyên nghiệp, không đồng bộ style/độ dày nét, và không tự đổi màu theo
// accent color của app.
//
// Không đổi kiểu dữ liệu `icon` từ String sang IconData ở tầng model/provider
// (một số nơi như HabitData có thể đã được lưu vào SharedPreferences dạng
// chuỗi, đổi kiểu sẽ vỡ dữ liệu cũ) — chỉ đổi TẦNG HIỂN THỊ: bảng ánh xạ bên
// dưới dịch emoji quen thuộc trong app sang icon Lucide tương ứng. Emoji nào
// CHƯA có trong bảng thì tự động fallback về hiện chính emoji đó (không vỡ
// UI), nên có thể bổ sung ánh xạ dần dần, an toàn.
//
// CỐ TÌNH GIỮ NGUYÊN EMOJI (không đưa vào bảng) ở những chỗ mang tính "vui
// vẻ, thân thiện" theo đúng yêu cầu:
// - Tin nhắn/avatar chat AI (🤖 trong chat_screen.dart)
// - Huy chương/vương miện xếp hạng (🏆 🏅 🥇 🥈 🥉 👑 trong home_screen.dart)
const Map<String, IconData> _kIconMap = {
  // Habits & quick actions
  '👀': LucideIcons.eye,
  '👁️': LucideIcons.eye,
  '📱': LucideIcons.smartphone,
  '😴': LucideIcons.moon,
  '🧪': LucideIcons.flaskConical,
  '🧠': LucideIcons.brain,
  '🌳': LucideIcons.trees,
  '🌿': LucideIcons.leaf,
  '☀️': LucideIcons.sun,
  '☕': LucideIcons.coffee,
  '⏰': LucideIcons.alarmClock,
  '⏱': LucideIcons.timer,
  '⚙️': LucideIcons.settings,
  '✅': LucideIcons.checkCircle2,
  '💬': LucideIcons.messageCircle,
  '📊': LucideIcons.barChart2,
  '🔒': LucideIcons.lock,
  '🔥': LucideIcons.flame,
  // Settings
  '📍': LucideIcons.mapPin,
  '🛡️': LucideIcons.shield,
  '🚪': LucideIcons.logOut,
  '🔤': LucideIcons.type,
  '🔋': LucideIcons.batteryCharging,
  '📋': LucideIcons.clipboardList,
  '💡': LucideIcons.lightbulb,
  '👓': LucideIcons.glasses,
  '🏃': LucideIcons.footprints,
  '🎯': LucideIcons.target,
  '🌐': LucideIcons.globe,
  '❓': LucideIcons.helpCircle,
  '🚀': LucideIcons.rocket,
  '📧': LucideIcons.mail,
  '🎨': LucideIcons.palette,
  '🌙': LucideIcons.moon,
  '🟠': LucideIcons.sunMedium, // "Bộ lọc ánh sáng xanh"
};

// Dùng thay cho `Text(icon, style: TextStyle(fontSize: ...))` ở mọi nơi
// render icon chức năng. Truyền `color` để icon tự đổi theo accent color
// thay vì luôn có màu emoji mặc định của hệ điều hành.
class AppIcon extends StatelessWidget {
  const AppIcon(this.glyph, {super.key, this.size = 22, this.color});

  final String glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final mapped = _kIconMap[glyph];
    if (mapped != null) {
      return Icon(mapped, size: size, color: color);
    }
    // Chưa có ánh xạ cho emoji này -> fallback an toàn, không vỡ UI.
    return Text(glyph, style: TextStyle(fontSize: size));
  }
}