// AppStrings chứa tất cả các chuỗi văn bản hiển thị trong ứng dụng.
// File này giúp tách riêng phần nội dung hiển thị khỏi logic, nên bạn không cần sửa UI khi thay đổi text.
//
// Cách hoạt động:
// - AppState tạo AppStrings dựa trên giá trị isVietnamese.
// - Các màn hình lấy strings từ state.strings.
// - Hàm getter trả về văn bản tiếng Việt hoặc tiếng Anh tương ứng.
class AppStrings {
  final bool vi;
  const AppStrings(this.vi);

  String get appTitle => 'EyeCare AI';

  String get home => vi ? 'Trang chủ' : 'Home';
  String get test => vi ? 'Kiểm tra' : 'Test';
  String get habits => vi ? 'Thói quen' : 'Habits';
  String get stats => vi ? 'Thống kê' : 'Stats';
  String get chat => vi ? 'Chat' : 'Chat';
  String get settings => vi ? 'Cài đặt' : 'Settings';

  String get goodMorning => vi ? 'Chào buổi sáng 👋' : 'Good morning 👋';
  String get welcomeTitle => 'EyeCare AI';
  String get eyeHealthScore => vi ? 'Điểm sức khỏe mắt' : 'Eye Health Score';
  String get goodProgress => vi ? 'Tiến triển tốt! Giữ vững.' : 'Good progress! Keep it up.';
  String get fromLastWeek => vi ? '+5 so với tuần trước' : '+5 from last week';

  String get screenTime => vi ? 'Thời gian màn hình' : 'Screen Time';
  String get outdoor => vi ? 'Ngoài trời' : 'Outdoor';
  String get breaks => vi ? 'Nghỉ ngơi' : 'Breaks';
  String get weeklyOverview => vi ? 'Tổng quan tuần' : 'Weekly Overview';
  String get aiSuggestions => vi ? 'Gợi ý AI' : 'AI Suggestions';
  String get takeBreak => vi ? 'Nghỉ theo quy tắc 20-20-20' : 'Take a 20-20-20 break';
  String get takeBreakSubtitle => vi ? 'Nhìn 6 mét ra xa trong 20 giây mỗi 20 phút.' : 'Look 20 feet away for 20 seconds every 20 minutes.';
  String get moreOutdoor => vi ? 'Đi ra ngoài nhiều hơn' : 'Get more outdoor time';
  String get moreOutdoorSubtitle => vi ? 'Ánh sáng tự nhiên giúp ngăn ngừa cận thị.' : 'Natural light helps prevent myopia progression.';
  String get improveSleep => vi ? 'Cải thiện giấc ngủ' : 'Improve sleep schedule';
  String get improveSleepSubtitle => vi ? 'Ngủ 7-8 tiếng để giảm mỏi mắt.' : 'Aim for 7-8 hours to reduce eye strain.';

  String get notifications => vi ? 'Thông báo' : 'Notifications';
  String get breakReminders => vi ? 'Nhắc nhở nghỉ ngơi' : 'Break Reminders';
  String get breakRemindersSubtitle => vi ? 'Nhận thông báo cho nghỉ ngơi 20-20-20' : 'Get notified for 20-20-20 breaks';
  String get eyeTestReminders => vi ? 'Nhắc nhở kiểm tra mắt' : 'Eye Test Reminders';
  String get eyeTestRemindersSubtitle => vi ? 'Nhắc kiểm tra thị lực hàng tuần' : 'Weekly vision screening alerts';
  String get habitTracking => vi ? 'Theo dõi thói quen' : 'Habit Tracking';
  String get habitTrackingSubtitle => vi ? 'Nhắc nhở hoàn thành thói quen hàng ngày' : 'Daily habit completion nudges';
  String get aiTips => vi ? 'Mẹo AI' : 'AI Tips';
  String get aiTipsSubtitle => vi ? 'Gợi ý chăm sóc mắt cá nhân' : 'Personalized eye health suggestions';

  // Phần này bao gồm các nhãn cho màn hình cài đặt và lựa chọn người dùng.
  String get preferences => vi ? 'Tùy chọn' : 'Preferences';
  String get darkMode => vi ? 'Chế độ tối' : 'Dark Mode';
  String get metricUnits => vi ? 'Đơn vị mét' : 'Metric Units';
  String get imperialUnits => vi ? 'Đơn vị Anh' : 'Imperial Units';
  String get metricUnitsSubtitle => vi ? 'Xem centimet và giờ' : 'Centimeters, hours';
  String get imperialUnitsSubtitle => vi ? 'Xem inch và giờ' : 'Inches, hours';
  String get measurementUnits => vi ? 'Đơn vị đo lường' : 'Measurement Units';
  String get dateTime => vi ? 'Ngày & Giờ' : 'Date & Time';
  String get metricMeters => vi ? 'Metric (Meters) / Mét' : 'Metric (Meters) / Mét';
  String get imperialFeet => vi ? 'Imperial (Feet)' : 'Imperial (Feet)';
  String get hour12 => vi ? '12-hour Clock / Định dạng 12 giờ' : '12-hour Clock / Định dạng 12 giờ';
  String get hour24 => vi ? '24-hour Clock / Định dạng 24 giờ' : '24-hour Clock / Định dạng 24 giờ';
  String get language => vi ? 'Ngôn ngữ' : 'Language';
  String get selectOption => vi ? 'Chọn lựa' : 'Select option';
  String get chooseValue => vi ? 'Chọn giá trị' : 'Choose value';
  String get cancel => vi ? 'Hủy' : 'Cancel';
  String get languageSubtitle => vi ? 'Chuyển giữa tiếng Anh và tiếng Việt' : 'Switch between English and Vietnamese';
  String get vietnamese => vi ? 'Tiếng Việt' : 'Vietnamese';
  String get english => vi ? 'Tiếng Anh' : 'English';

  String get more => vi ? 'Khác' : 'More';
  String get privacySecurity => vi ? 'Quyền riêng tư & Bảo mật' : 'Privacy & Security';
  String get termsOfService => vi ? 'Điều khoản dịch vụ' : 'Terms of Service';
  String get helpSupport => vi ? 'Trợ giúp & Hỗ trợ' : 'Help & Support';
  String get signOut => vi ? 'Đăng xuất' : 'Sign Out';
  String get version => vi ? 'EyeCare AI v1.0.0' : 'EyeCare AI v1.0.0';

  String get aiAssistant => vi ? 'Trợ lý AI' : 'AI Assistant';
  String get online => vi ? 'Trực tuyến' : 'Online';
  String get askAboutEyeHealth => vi ? 'Hỏi về sức khỏe mắt...' : 'Ask about eye health...';
  List<String> get quickPrompts => vi
      ? [
          'Làm sao giảm mỏi mắt?',
          'Thức ăn tốt cho mắt',
          'Giải thích quy tắc 20-20-20',
          'Khi nào khám mắt?',
        ]
      : [
          'How to reduce eye strain?',
          'Best foods for eye health',
          '20-20-20 rule explained',
          'When to see an eye doctor?',
        ];

  String get eyeTest => vi ? 'Nhắc nghỉ mắt' : 'Break Reminder';
  String get snellenScreening => vi ? 'Cài nhắc nghỉ mắt sau khoảng thời gian' : 'Set a break reminder after a time interval';
  String get reminderSet => vi ? 'Đã bật nhắc nghỉ mắt' : 'Reminder set';
  String get reminderInterval => vi ? 'Nhắc nhở sau' : 'Reminder after';
  String get minutes => vi ? 'phút' : 'mins';
  String get confirm => vi ? 'Xác nhận' : 'Confirm';
  String get visionScreening => vi ? 'Kiểm tra thị lực' : 'Vision Screening';
  String get visionScreeningTitle => vi ? 'Kiểm tra thị lực nhanh giúp ước lượng thị lực của bạn. Hãy đứng cách màn hình khoảng 2 mét và đảm bảo đủ sáng.' : 'This quick Snellen chart test helps estimate your visual acuity. Find a well-lit area and stand about 6 feet from your screen.';
  String get ensureLighting => vi ? 'Đảm bảo ánh sáng tốt' : 'Ensure good lighting';
  String get maintainDistance => vi ? 'Giữ khoảng cách ~2 m' : 'Maintain ~6 ft distance';
  String get wearGlasses => vi ? 'Đeo kính nếu bạn thường dùng' : 'Wear glasses if you normally do';
  String get startTest => vi ? 'Bắt đầu kiểm tra' : 'Start Test';
  String get coverYour => vi ? 'Che mắt của bạn' : 'Cover Your';
  String get useHandCover => vi ? 'Dùng tay che mắt. Giữ mắt còn lại nhìn vào màn hình.' : 'Use your hand to cover your eye. Keep the uncovered eye focused on the screen.';
  String get continueText => vi ? 'Tiếp tục' : 'Continue';
  String get readSmallestLine => vi ? 'Đọc dòng nhỏ nhất bạn nhìn rõ' : 'Read the smallest line you can see clearly';
  String get eyeLabelLeft => vi ? 'Mắt trái' : 'Left Eye';
  String get eyeLabelRight => vi ? 'Mắt phải' : 'Right Eye';
  String get selectYourResult => vi ? 'Chọn kết quả của bạn:' : 'Select your result:';
  String get testComplete => vi ? 'Hoàn thành kiểm tra!' : 'Test Complete!';
  String get aiInsight => vi ? 'Thông tin AI' : 'AI Insight';
  String get retakeTest => vi ? 'Kiểm tra lại' : 'Retake Test';

  String get dailyHabits => vi ? 'Thói quen hàng ngày' : 'Daily Habits';
  String get trackRoutines => vi ? 'Theo dõi thói quen thân thiện với mắt' : 'Track your eye-friendly routines';
  String get todaysProgress => vi ? 'Tiến trình hôm nay' : 'Today\'s Progress';
  String get target => vi ? 'Mục tiêu' : 'Target';
  String get habitsCompleted => vi ? 'thói quen đã hoàn thành' : 'habits completed';

  String completedHabits(int completed, int total) =>
      vi ? '$completed/$total thói quen đã hoàn thành' : '$completed of $total habits completed';

  // habitTitle chuyển id của thói quen thành tiêu đề phù hợp cho màn hình.
  // Thêm case mới nếu bạn mở rộng danh sách thói quen.
  // habitTitle chuyển id nội bộ của thói quen thành tiêu đề hiển thị.
  // Nếu thêm thói quen mới, hãy mở rộng switch-case ở đây.
  String habitTitle(String id) {
    switch (id) {
      case 'reading':
        return vi ? 'Thời gian đọc sách' : 'Reading Time';
      case 'phone':
        return vi ? 'Sử dụng điện thoại' : 'Phone Usage';
      case 'sleep':
        return vi ? 'Giấc ngủ' : 'Sleep';
      case 'outdoor':
        return vi ? 'Thời gian ngoài trời' : 'Outdoor Time';
      case 'breaks':
        return vi ? 'Nghỉ ngơi mắt' : 'Eye Breaks';
      default:
        return id;
    }
  }

  // habitSubtitle mô tả nguồn dữ liệu thật đứng sau mỗi thói quen
  // (cảm biến / API hệ điều hành nào đang được dùng để đo).
  String habitSubtitle(String id) {
    switch (id) {
      case 'reading':
        return vi ? 'Ánh sáng môi trường & gia tốc kế' : 'Ambient light & accelerometer';
      case 'phone':
        return vi ? 'Thời gian màn hình (hệ điều hành)' : 'Screen-on time (OS)';
      case 'sleep':
        return vi ? 'Đêm qua — gia tốc kế' : 'Last night — accelerometer';
      case 'outdoor':
        return vi ? 'GPS & cảm biến UV' : 'GPS & UV sensor';
      case 'breaks':
        return vi ? 'Nhận diện ánh nhìn qua camera trước' : 'Front camera gaze detection';
      default:
        return '';
    }
  }

  // habitUnit chuyển đơn vị thói quen sang văn bản phù hợp.
  // Bạn có thể mở rộng đơn vị mới ở đây.
  // habitUnit chuyển đơn vị đo của thói quen sang text phù hợp.
  // Hiện tại, một số đơn vị giữ nguyên ở cả hai ngôn ngữ.
  String habitUnit(String unit) {
    switch (unit) {
      case 'cm':
        return vi ? 'cm' : 'cm';
      case 'hrs':
        return vi ? 'giờ' : 'hrs';
      case 'min':
        return vi ? 'phút' : 'min';
      case 'times':
        return vi ? 'lần' : 'times';
      case 'breaks':
        return vi ? 'lần nghỉ' : 'breaks';
      case 'glasses':
        return vi ? 'ly' : 'glasses';
      default:
        return unit;
    }
  }

  String stepCount(int step, int total) =>
      vi ? 'Bước $step trong $total' : 'Step $step of $total';

  List<String> get weeklyLabels => vi
      ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<String> get monthlyLabels =>
      ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];

  String get score => vi ? 'Điểm' : 'Score';
  String get sleep => vi ? 'Giấc ngủ' : 'Sleep';
  String get hourUnit => vi ? 'giờ' : 'hrs';
  String get pointUnit => vi ? 'điểm' : 'pts';
  String get visionAiFeedback => vi ? 'Thị lực của bạn nằm trong phạm vi bình thường. Mắt phải của bạn cho thấy khả năng nhìn kém hơn một chút — hãy cân nhắc khám mắt chuyên nghiệp nếu tình trạng này kéo dài.' : 'Your vision is within normal range. Your right eye shows slightly lower acuity — consider scheduling a professional eye exam if this persists.';

  String get statistics => vi ? 'Thống kê' : 'Statistics';
  String get trackTrends => vi ? 'Theo dõi xu hướng sức khỏe mắt' : 'Track your eye health trends';
  String get weekly => vi ? 'Hàng tuần' : 'Weekly';
  String get monthly => vi ? 'Hàng tháng' : 'Monthly';
  String get habitCompletion => vi ? 'Hoàn thành thói quen' : 'Habit Completion';
  String get streak => vi ? 'Chuỗi' : 'Streak';
  String get dayStreak => vi ? 'ngày liên tiếp' : 'day streak';
}
