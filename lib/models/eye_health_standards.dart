// Các thông số tiêu chuẩn về sức khỏe mắt dùng để so sánh với câu trả lời
// khảo sát của người dùng và gợi ý mục tiêu (target) phù hợp.
//
// NGUỒN THAM KHẢO (tổng hợp, mang tính khuyến nghị chung — KHÔNG thay thế tư
// vấn y khoa): quy tắc 20-20-20 của American Optometric Association, khuyến
// nghị thời gian hoạt động ngoài trời để phòng cận thị (WHO / các nghiên cứu
// nhãn khoa nhi), khuyến nghị giấc ngủ của National Sleep Foundation.
enum AgeGroup { child, teen, adult }

class EyeHealthStandards {
  EyeHealthStandards._();

  // Khoảng cách đọc / nhìn màn hình tối thiểu nên giữ (cm).
  static const double minReadingDistanceCm = 30;
  static const double recommendedReadingDistanceCm = 40;

  // Thời gian hoạt động ngoài trời khuyến nghị mỗi ngày (phút),
  // trẻ em/thiếu niên cần nhiều hơn để giảm nguy cơ cận thị.
  static int recommendedOutdoorMinutes(AgeGroup group) {
    switch (group) {
      case AgeGroup.child:
        return 120;
      case AgeGroup.teen:
        return 90;
      case AgeGroup.adult:
        return 60;
    }
  }

  // Thời gian ngủ khuyến nghị mỗi đêm (giờ).
  static (double min, double max) recommendedSleepHours(AgeGroup group) {
    switch (group) {
      case AgeGroup.child:
        return (9, 11);
      case AgeGroup.teen:
        return (8, 10);
      case AgeGroup.adult:
        return (7, 9);
    }
  }

  // Thời gian dùng màn hình giải trí khuyến nghị mỗi ngày (giờ).
  static double recommendedRecreationalScreenHours(AgeGroup group) {
    switch (group) {
      case AgeGroup.child:
        return 1;
      case AgeGroup.teen:
        return 2;
      case AgeGroup.adult:
        return 3;
    }
  }

  // Số lần nghỉ mắt khuyến nghị mỗi ngày, dựa trên quy tắc 20-20-20
  // (mỗi 20 phút dùng màn hình nên có 1 lần nghỉ).
  static int recommendedBreaksPerDay(double screenHoursPerDay) {
    final breaks = (screenHoursPerDay * 60 / 20).ceil();
    return breaks < 6 ? 6 : breaks;
  }

  static String ageGroupLabel(AgeGroup group, bool vi) {
    switch (group) {
      case AgeGroup.child:
        return vi ? 'Dưới 13 tuổi' : 'Under 13';
      case AgeGroup.teen:
        return vi ? '13 - 18 tuổi' : '13 - 18';
      case AgeGroup.adult:
        return vi ? 'Trên 18 tuổi' : 'Over 18';
    }
  }
}

// SurveyAnswers gói lại toàn bộ câu trả lời khảo sát của người dùng.
class SurveyAnswers {
  SurveyAnswers({
    required this.ageGroup,
    required this.screenHoursPerDay,
    required this.outdoorMinutesPerDay,
    required this.readingDistanceCm,
    required this.sleepHoursPerNight,
    required this.breaksPerDay,
  });

  final AgeGroup ageGroup;
  final double screenHoursPerDay;
  final double outdoorMinutesPerDay;
  final double readingDistanceCm;
  final double sleepHoursPerNight;
  final double breaksPerDay;
}

// Một dòng so sánh: chỉ số hiện tại của người dùng vs. chuẩn khuyến nghị.
class ComparisonRow {
  ComparisonRow({
    required this.id,
    required this.currentValue,
    required this.recommendedLabel,
    required this.isGood,
    required this.tip,
  });

  final String id; // khớp với HabitData.id nếu có, hoặc 'reading_distance'
  final double currentValue;
  final String recommendedLabel;
  final bool isGood;
  final String tip;
}

class SurveyResult {
  SurveyResult({required this.rows, required this.targets});

  final List<ComparisonRow> rows;
  // targets: id habit -> giá trị target mới nên áp dụng (chỉ gồm các habit
  // thực sự tồn tại trên trang Habits: phone, outdoor, sleep, breaks).
  final Map<String, double> targets;
}

SurveyResult evaluateSurvey(SurveyAnswers a, bool vi) {
  final outdoorTarget = EyeHealthStandards.recommendedOutdoorMinutes(a.ageGroup);
  final sleepRange = EyeHealthStandards.recommendedSleepHours(a.ageGroup);
  final screenTarget = EyeHealthStandards.recommendedRecreationalScreenHours(a.ageGroup);
  final breaksTarget = EyeHealthStandards.recommendedBreaksPerDay(a.screenHoursPerDay);

  final rows = <ComparisonRow>[
    ComparisonRow(
      id: 'phone',
      currentValue: a.screenHoursPerDay,
      recommendedLabel: vi ? '≤ $screenTarget giờ/ngày' : '≤ $screenTarget hrs/day',
      isGood: a.screenHoursPerDay <= screenTarget,
      tip: vi
          ? 'Ưu tiên giảm dần thời gian giải trí trên màn hình, dùng chế độ tối và nghỉ mắt thường xuyên.'
          : 'Try trimming recreational screen time gradually, use dark mode, and take frequent breaks.',
    ),
    ComparisonRow(
      id: 'outdoor',
      currentValue: a.outdoorMinutesPerDay,
      recommendedLabel: vi ? '≥ $outdoorTarget phút/ngày' : '≥ $outdoorTarget min/day',
      isGood: a.outdoorMinutesPerDay >= outdoorTarget,
      tip: vi
          ? 'Ánh sáng tự nhiên ngoài trời giúp giảm nguy cơ cận thị, đặc biệt quan trọng với trẻ em.'
          : 'Natural outdoor light helps lower myopia risk, especially important for children.',
    ),
    ComparisonRow(
      id: 'reading_distance',
      currentValue: a.readingDistanceCm,
      recommendedLabel: vi
          ? '≥ ${EyeHealthStandards.minReadingDistanceCm.round()} cm'
          : '≥ ${EyeHealthStandards.minReadingDistanceCm.round()} cm',
      isGood: a.readingDistanceCm >= EyeHealthStandards.minReadingDistanceCm,
      tip: vi
          ? 'Giữ khoảng cách tối thiểu 30cm khi đọc sách hoặc dùng điện thoại, lý tưởng là 40cm.'
          : 'Keep at least 30cm distance while reading or using your phone, ideally 40cm.',
    ),
    ComparisonRow(
      id: 'sleep',
      currentValue: a.sleepHoursPerNight,
      recommendedLabel: vi
          ? '${sleepRange.$1.round()} - ${sleepRange.$2.round()} giờ/đêm'
          : '${sleepRange.$1.round()} - ${sleepRange.$2.round()} hrs/night',
      isGood: a.sleepHoursPerNight >= sleepRange.$1 && a.sleepHoursPerNight <= sleepRange.$2,
      tip: vi
          ? 'Ngủ đủ giấc giúp mắt phục hồi và giảm khô mắt, mỏi mắt vào ban ngày.'
          : 'Enough sleep lets your eyes recover and reduces dryness and strain during the day.',
    ),
    ComparisonRow(
      id: 'breaks',
      currentValue: a.breaksPerDay,
      recommendedLabel: vi ? '≥ $breaksTarget lần/ngày' : '≥ $breaksTarget times/day',
      isGood: a.breaksPerDay >= breaksTarget,
      tip: vi
          ? 'Áp dụng quy tắc 20-20-20: cứ 20 phút màn hình, nghỉ mắt 20 giây, nhìn xa 6 mét.'
          : 'Follow the 20-20-20 rule: every 20 minutes of screen time, rest 20 seconds looking 20 feet away.',
    ),
  ];

  final targets = <String, double>{
    'phone': screenTarget,
    'outdoor': outdoorTarget.toDouble(),
    'sleep': sleepRange.$2,
    'breaks': breaksTarget.toDouble(),
  };

  return SurveyResult(rows: rows, targets: targets);
}
