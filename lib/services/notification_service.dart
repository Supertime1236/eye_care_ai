import 'dart:io';
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// NotificationService quản lý toàn bộ thông báo cục bộ của app.
//
// Có 2 loại thông báo cho tính năng nhắc nghỉ mắt:
// 1. showInstantNotification: bắn ngay lập tức (dùng khi countdown đang chạy
//    trong app và vừa về 0 trong lúc người dùng đang mở app).
// 2. scheduleBreakAlarm: LÊN LỊCH TRƯỚC cho một thời điểm trong tương lai,
//    do hệ điều hành tự bắn đúng giờ dù app đã bị đóng/thu nhỏ — đây là cách
//    đảm bảo người dùng vẫn được nhắc kể cả khi không mở app.
//
// ÂM THANH RIÊNG: nếu bạn thêm 1 file âm thanh vào
// android/app/src/main/res/raw/eye_break_alert.mp3 (hoặc .wav/.ogg — KHÔNG có
// khoảng trắng/ký tự hoa trong tên file, chỉ chữ thường/số/gạch dưới), app sẽ
// tự dùng file đó làm âm thanh thông báo thay vì âm mặc định của hệ thống.
// Nếu chưa có file này, code vẫn chạy bình thường với âm thanh mặc định.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'eye_break_channel';
  static const _channelName = 'Eye Break Reminder';
  static const _alarmNotificationId = 1001;

  // Thông báo GHIM (ongoing) hiển thị thời gian còn lại trong lúc đếm ngược
  // đang chạy — kênh riêng vì cần im lặng (không kêu/rung mỗi lần cập nhật
  // nội dung), khác hẳn với thông báo hết-giờ ở trên.
  static const _ongoingChannelId = 'break_ongoing_channel';
  static const _ongoingChannelName = 'Break Reminder Countdown';
  static const ongoingNotificationId = 1002;

  // Đổi tên này nếu bạn đặt tên file âm thanh khác trong thư mục res/raw.
  static const String _customSoundResourceName = 'eye_break_alert';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Tạo kênh thông báo với âm thanh riêng (nếu có file) — phải tạo kênh
    // TRƯỚC khi gửi thông báo đầu tiên, vì Android không cho đổi âm thanh của
    // một kênh đã tồn tại (phải tạo kênh mới nếu muốn đổi âm sau này).
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Nhắc nghỉ mắt theo quy tắc 20-20-20',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound(_customSoundResourceName),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    await androidPlugin?.createNotificationChannel(channel);

    // Kênh riêng cho thông báo ghim đếm ngược: importance thấp, không âm
    // thanh/rung vì được cập nhật liên tục (mỗi giây) chứ không phải bắn 1
    // lần như thông báo hết giờ.
    const ongoingChannel = AndroidNotificationChannel(
      _ongoingChannelId,
      _ongoingChannelName,
      description: 'Hiển thị thời gian còn lại tới lần nhắc nghỉ mắt tiếp theo',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    await androidPlugin?.createNotificationChannel(ongoingChannel);

    await androidPlugin?.requestNotificationsPermission();

    await notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  // Các quyền dưới đây (báo thức chính xác, miễn trừ tối ưu pin) dùng
  // package permission_handler / plugin cần một Activity ĐÃ ATTACH xong để
  // hoạt động. Nếu gọi quá sớm (trước runApp/trước khi Activity gắn xong —
  // ví dụ ngay trong main() trước khi khung hình đầu tiên được vẽ), plugin sẽ
  // ném lỗi "Permission launcher not found" và không hiện dialog gì cả.
  //
  // => Hàm này PHẢI được gọi SAU khi widget tree đã build xong lần đầu, ví
  // dụ trong initState() của widget gốc kèm addPostFrameCallback, KHÔNG được
  // gọi trong main() trước runApp().
  Future<void> requestDeferredSystemPermissions() async {
    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // requestExactAlarmsPermission() MỞ THẲNG một màn hình Settings của hệ
    // thống (ảnh "Chuông báo và lời nhắc") — nếu gọi lại mỗi lần app khởi
    // động thì người dùng cứ bị đưa tới màn đó liên tục dù đã cấp/từ chối rồi
    // trước đó. Chỉ gọi hàm này MỘT LẦN DUY NHẤT trong vòng đời cài đặt app.
    final prefs = await SharedPreferences.getInstance();
    const askedKey = 'pref_exact_alarm_permission_asked';
    if (!(prefs.getBool(askedKey) ?? false)) {
      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (_) {
        // Bỏ qua nếu Activity chưa sẵn sàng hoặc thiết bị không hỗ trợ.
      }
      await prefs.setBool(askedKey, true);
    }

    // NHIỀU HÃNG MÁY (Xiaomi/MIUI, Oppo, Vivo, Samsung...) tự ý "diệt" tiến
    // trình app chạy nền để tiết kiệm pin — khi đó timer đang đếm VÀ báo thức
    // đã lên lịch đều có thể không bắn đúng giờ. Xin miễn trừ tối ưu hoá pin
    // giúp giảm đáng kể tình trạng này. Cũng chỉ hỏi 1 LẦN DUY NHẤT như quyền
    // báo thức chính xác ở trên, để không làm phiền người dùng mỗi lần mở app.
    const batteryAskedKey = 'pref_battery_optimization_asked';
    if (!(prefs.getBool(batteryAskedKey) ?? false)) {
      try {
        await Permission.ignoreBatteryOptimizations.request();
      } catch (_) {
        // Bỏ qua nếu thiết bị/ROM không hỗ trợ dialog này.
      }
      await prefs.setBool(batteryAskedKey, true);
    }
  }

  NotificationDetails _details({bool insistent = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Nhắc nghỉ mắt theo quy tắc 20-20-20',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        sound: RawResourceAndroidNotificationSound(_customSoundResourceName),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
        // FLAG_INSISTENT (4): lặp lại âm thanh + rung liên tục cho đến khi
        // người dùng chạm vào thông báo, giống chuông báo thức. Chỉ bật cho
        // thông báo hết-giờ-nghỉ-mắt thật sự, không dùng cho thông báo phụ.
        additionalFlags: insistent ? Int32List.fromList(<int>[4]) : null,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    bool insistent = false,
  }) async {
    await initialize();
    await notifications.show(0, title, body, _details(insistent: insistent));
  }

  // Lên lịch một thông báo cho thời điểm `when` trong tương lai — hệ điều
  // hành sẽ tự bắn đúng giờ này dù app đang đóng hay chạy nền.
  Future<void> scheduleBreakAlarm(
    DateTime when, {
    required String title,
    required String body,
  }) async {
    await initialize();
    await cancelBreakAlarm();

    final scheduledDate = tz.TZDateTime.from(when, tz.local);
    // THỨ TỰ ƯU TIÊN CÁC CHẾ ĐỘ LÊN LỊCH (từ đáng tin cậy nhất):
    // 1. alarmClock: hệ thống coi như MỘT BÁO THỨC THẬT — gần như miễn nhiễm
    //    với Doze/App Standby và các trình diệt tiến trình nền của OEM
    //    (Xiaomi/MIUI, Oppo, Vivo...), đây là lý do chính khiến bản trước
    //    "hết giờ vẫn không báo" khi app bị hệ điều hành đóng ở nền. Nhược
    //    điểm nhỏ: có thể hiện icon đồng hồ báo thức trên thanh trạng thái.
    // 2. exactAllowWhileIdle: dùng nếu alarmClock ném lỗi (hiếm, một số ROM
    //    chặn riêng chế độ này).
    // 3. inexactAllowWhileIdle: phương án cuối, không cần quyền đặc biệt,
    //    đảm bảo vẫn có thông báo dù có thể trễ vài phút.
    for (final mode in [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await notifications.zonedSchedule(
          _alarmNotificationId,
          title,
          body,
          scheduledDate,
          _details(insistent: true),
          androidScheduleMode: mode,
        );
        return;
      } catch (_) {
        // Thử chế độ kế tiếp trong danh sách.
      }
    }
  }

  // Kiểm tra người dùng đã cấp quyền "Báo thức & lời nhắc chính xác" chưa —
  // dùng để UI hiện gợi ý bật quyền này nếu bị tắt (khác với lúc mới cài,
  // requestExactAlarmsPermission() chỉ tự hỏi đúng 1 lần).
  Future<bool> canScheduleExactAlarms() async {
    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? true;
  }

  // Mở thẳng màn hình Settings hệ thống để người dùng tự cấp lại quyền báo
  // thức chính xác nếu trước đó đã từ chối.
  Future<void> openExactAlarmSettings() async {
    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  // Android 14+ (API 34) THẮT CHẶT thêm: kể cả đã có quyền
  // USE_FULL_SCREEN_INTENT trong Manifest, thông báo hết-giờ-nghỉ-mắt vẫn có
  // thể chỉ hiện dạng thông báo thường (không tự bật màn hình / hiện pop-up
  // toàn màn hình) nếu người dùng chưa bật riêng công tắc "Hiển thị toàn màn
  // hình" cho app trong Settings — đây là nguyên nhân phổ biến khiến "Break
  // Reminder" có báo nhưng không thấy pop-up như các app báo thức khác.
  // Hàm này mở thẳng đúng màn hình cài đặt đó trên máy Android 14+.
  Future<void> openFullScreenIntentSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final intent = AndroidIntent(
        action: 'android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT',
        data: 'package:com.eyecare.eye_care_ai',
      );
      await intent.launch();
    } catch (_) {
      // Máy chạy Android < 14 không có màn hình cài đặt này -> bỏ qua.
    }
  }

  Future<void> cancelBreakAlarm() async {
    await notifications.cancel(_alarmNotificationId);
  }

  // Hiện/cập nhật thông báo GHIM trên thanh thông báo, hiển thị mm:ss còn
  // lại. `ongoing: true` + `autoCancel: false` khiến người dùng không vuốt bỏ
  // được (chỉ biến mất khi cancelOngoingCountdown() được gọi, tức là khi
  // dừng/hết giờ) — đúng ý "ghim luôn trên thanh thông báo". `onlyAlertOnce`
  // đảm bảo mỗi lần cập nhật không kêu/rung lại.
  Future<void> updateOngoingCountdown({
    required int secondsRemaining,
    required String title,
    required String remainingSuffix,
    DateTime? endAt,
  }) async {
    await initialize();
    final clamped = secondsRemaining < 0 ? 0 : secondsRemaining;
    final details = AndroidNotificationDetails(
      _ongoingChannelId,
      _ongoingChannelName,
      channelDescription: 'Hiển thị thời gian còn lại tới lần nhắc nghỉ mắt tiếp theo',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showWhen: false,
    );

    // Hiện giờ đồng hồ sẽ nhắc (VD "Sẽ nhắc lúc 15:40") thay vì đếm ngược
    // mm:ss, vì đếm ngược theo phút/giây dễ gây cảm giác "chưa đủ đô" và khó
    // liếc nhanh trên thanh thông báo hơn một mốc giờ cố định.
    final at = endAt ?? DateTime.now().add(Duration(seconds: clamped));
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');

    await notifications.show(
      ongoingNotificationId,
      title,
      '$remainingSuffix $hh:$mm',
      NotificationDetails(android: details),
    );
  }

  Future<void> cancelOngoingCountdown() async {
    await notifications.cancel(ongoingNotificationId);
  }

  // Khi app bị đưa xuống nền, Timer trong Dart không còn chạy được nữa nên
  // updateOngoingCountdown() sẽ ngừng cập nhật — người dùng kéo thanh thông
  // báo ra sẽ thấy mm:ss "đứng hình" mãi ở giá trị cuối cùng trước khi rời
  // app, gây cảm giác app bị treo. Để tránh nhầm lẫn này, ngay khi app
  // chuyển xuống nền, đổi nội dung thông báo ghim sang giờ hẹn CỐ ĐỊNH
  // (VD: "Sẽ nhắc lúc 15:40") thay vì con số đang chạy — báo thức thật
  // (scheduleBreakAlarm) vẫn tự bắn đúng giờ này dù thông báo ghim không
  // còn "tick" nữa.
  Future<void> showStaticOngoingUntil({
    required DateTime endAt,
    required String title,
    required String untilPrefix,
  }) async {
    await initialize();
    final hh = endAt.hour.toString().padLeft(2, '0');
    final mm = endAt.minute.toString().padLeft(2, '0');
    const details = AndroidNotificationDetails(
      _ongoingChannelId,
      _ongoingChannelName,
      channelDescription: 'Hiển thị thời gian còn lại tới lần nhắc nghỉ mắt tiếp theo',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showWhen: false,
    );
    await notifications.show(
      ongoingNotificationId,
      title,
      '$untilPrefix $hh:$mm',
      const NotificationDetails(android: details),
    );
  }
}
