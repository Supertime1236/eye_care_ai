import 'package:flutter/material.dart';

/// Một bậc xếp hạng (rank tier) — giống các "League" trong Duolingo nhưng
/// dùng danh hiệu tự chế theo chủ đề "chăm sóc mắt" để phù hợp với app.
/// `minStreakDays` là số ngày duy trì streak (điểm sức khỏe mắt >= 80% liên
/// tục) TỐI THIỂU để đạt bậc này — xem HabitProvider.streakDays /
/// DeviceDataService.calculateStreakDays().
class RankTier {
  const RankTier({
    required this.id,
    required this.minStreakDays,
    required this.emoji,
    required this.nameVi,
    required this.nameEn,
    required this.titleVi,
    required this.titleEn,
    required this.congratsVi,
    required this.congratsEn,
    required this.color,
  });

  final String id;
  final int minStreakDays;
  final String emoji;

  /// Tên bậc (ví dụ "Đồng", "Bạc"...).
  final String nameVi;
  final String nameEn;

  /// Danh hiệu tự chế đầy đủ (ví dụ "Siêu Anh Hùng Mắt").
  final String titleVi;
  final String titleEn;

  /// Câu chúc mừng hiển thị khi vừa lên hạng.
  final String congratsVi;
  final String congratsEn;

  final Color color;

  String name(bool vi) => vi ? nameVi : nameEn;
  String title(bool vi) => vi ? titleVi : titleEn;
  String congrats(bool vi) => vi ? congratsVi : congratsEn;
}

/// Toàn bộ hệ thống bậc xếp hạng, xếp từ THẤP -> CAO theo minStreakDays.
/// Chỉnh sửa/thêm bậc ở đây là đủ — mọi nơi khác (RankProvider, RankScreen,
/// bảng xếp hạng) đều tự suy ra từ danh sách này.
class RankTiers {
  RankTiers._();

  static const List<RankTier> all = [
    RankTier(
      id: 'unranked',
      minStreakDays: 0,
      emoji: '🥚',
      nameVi: 'Chưa xếp hạng',
      nameEn: 'Unranked',
      titleVi: 'Tân Binh Mắt Cận',
      titleEn: 'Rookie Blinker',
      congratsVi: 'Bắt đầu chuỗi ngày chăm mắt đầu tiên của bạn nào!',
      congratsEn: 'Start your very first eye-care streak!',
      color: Color(0xFF9CA3AF),
    ),
    RankTier(
      id: 'bronze',
      minStreakDays: 3,
      emoji: '🥉',
      nameVi: 'Đồng',
      nameEn: 'Bronze',
      titleVi: 'Chiến Binh Chớp Mắt',
      titleEn: 'Blink Warrior',
      congratsVi: 'Chúc mừng bạn đạt danh hiệu Chiến Binh Chớp Mắt!',
      congratsEn: 'Congrats, you earned the Blink Warrior title!',
      color: Color(0xFFCD7C2F),
    ),
    RankTier(
      id: 'silver',
      minStreakDays: 10,
      emoji: '🥈',
      nameVi: 'Bạc',
      nameEn: 'Silver',
      titleVi: 'Vệ Binh Thị Lực',
      titleEn: 'Vision Guardian',
      congratsVi: 'Chúc mừng bạn đạt danh hiệu Vệ Binh Thị Lực!',
      congratsEn: 'Congrats, you earned the Vision Guardian title!',
      color: Color(0xFFB0B7C3),
    ),
    RankTier(
      id: 'gold',
      minStreakDays: 20,
      emoji: '🥇',
      nameVi: 'Vàng',
      nameEn: 'Gold',
      titleVi: 'Cao Thủ Dưỡng Nhãn',
      titleEn: 'Eye-Care Master',
      congratsVi: 'Chúc mừng bạn đạt danh hiệu Cao Thủ Dưỡng Nhãn!',
      congratsEn: 'Congrats, you earned the Eye-Care Master title!',
      color: Color(0xFFF5B700),
    ),
    RankTier(
      id: 'platinum',
      minStreakDays: 40,
      emoji: '💠',
      nameVi: 'Bạch Kim',
      nameEn: 'Platinum',
      titleVi: 'Huyền Thoại Mắt Sáng',
      titleEn: 'Bright-Eyes Legend',
      congratsVi: 'Chúc mừng bạn đạt danh hiệu Huyền Thoại Mắt Sáng!',
      congratsEn: 'Congrats, you earned the Bright-Eyes Legend title!',
      color: Color(0xFF5EEAD4),
    ),
    RankTier(
      id: 'diamond',
      minStreakDays: 70,
      emoji: '💎',
      nameVi: 'Kim Cương',
      nameEn: 'Diamond',
      titleVi: 'Siêu Anh Hùng Mắt',
      titleEn: 'Eye Super Hero',
      congratsVi: 'Chúc mừng bạn đạt danh hiệu Siêu Anh Hùng Mắt!',
      congratsEn: 'Congrats, you earned the Eye Super Hero title!',
      color: Color(0xFF60A5FA),
    ),
    RankTier(
      id: 'master',
      minStreakDays: 120,
      emoji: '👑',
      nameVi: 'Cao Thủ Tối Thượng',
      nameEn: 'Supreme Master',
      titleVi: 'Thần Nhãn Vô Cực',
      titleEn: 'Infinite Eye Deity',
      congratsVi: 'Chúc mừng bạn đạt danh hiệu Thần Nhãn Vô Cực — đỉnh cao chăm mắt!',
      congratsEn: 'Congrats, you earned the Infinite Eye Deity title — top of eye care!',
      color: Color(0xFFA78BFA),
    ),
  ];

  /// Bậc hiện tại ứng với số ngày streak cho trước.
  static RankTier forStreak(int streakDays) {
    var current = all.first;
    for (final tier in all) {
      if (streakDays >= tier.minStreakDays) {
        current = tier;
      } else {
        break;
      }
    }
    return current;
  }

  /// Bậc kế tiếp (null nếu đã ở bậc cao nhất).
  static RankTier? nextTier(int streakDays) {
    final current = forStreak(streakDays);
    final index = all.indexOf(current);
    if (index == -1 || index == all.length - 1) return null;
    return all[index + 1];
  }
}
