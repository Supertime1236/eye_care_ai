import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

    await androidPlugin?.requestNotificationsPermission();

    // requestExactAlarmsPermission() MỞ THẲNG một màn hình Settings của hệ
    // thống (ảnh "Chuông báo và lời nhắc") — nếu gọi lại mỗi lần app khởi
    // động thì người dùng cứ bị đưa tới màn đó liên tục dù đã cấp/từ chối rồi
    // trước đó. Chỉ gọi hàm này MỘT LẦN DUY NHẤT trong vòng đời cài đặt app.
    final prefs = await SharedPreferences.getInstance();
    const askedKey = 'pref_exact_alarm_permission_asked';
    if (!(prefs.getBool(askedKey) ?? false)) {
      await androidPlugin?.requestExactAlarmsPermission();
      await prefs.setBool(askedKey, true);
    }

    await notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
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

    await notifications.zonedSchedule(
      _alarmNotificationId,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details(insistent: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelBreakAlarm() async {
    await notifications.cancel(_alarmNotificationId);
  }
}
