import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/device_data_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/settings_toggle_tile.dart';
import '../widgets/shared_widgets.dart';

// EyeBreakScreen thay thế hoàn toàn màn hình Eye Test cũ.
// Đây là một bộ đếm giờ nhắc người dùng nghỉ mắt theo chu kỳ (mặc định theo
// quy tắc 20-20-20). Khi hết giờ, một màn hình toàn màn hình hiện ra yêu cầu
// người dùng nhìn xa trong 20 giây, sau đó tự xác nhận đã nghỉ — số lần nghỉ
// này được ghi nhận THẬT (qua HabitProvider.recordEyeBreak) và đồng bộ với habit
// "Eye Breaks" ở trang Habits.
class EyeBreakScreen extends StatefulWidget {
  const EyeBreakScreen({super.key});

  @override
  State<EyeBreakScreen> createState() => _EyeBreakScreenState();
}

class _EyeBreakScreenState extends State<EyeBreakScreen> with WidgetsBindingObserver {
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _breakPromptShowing = false;
  // Mốc thời gian tuyệt đối lúc hết giờ — đây là NGUỒN SỰ THẬT DUY NHẤT cho
  // thời gian còn lại. _secondsRemaining chỉ là giá trị hiển thị được TÍNH
  // LẠI từ mốc này mỗi tick, không phải đếm lùi độc lập — vì Timer.periodic
  // có thể bị hệ điều hành tạm dừng khi app chạy nền một lúc rồi mở lại, nếu
  // chỉ đếm lùi theo số tick thực sự chạy được thì sẽ bị "đứng hình" giống
  // lỗi trước đây (thoát app lúc còn 24:39, quay lại vẫn thấy 24:39).
  DateTime? _endAt;

  static const _intervalOptions = [10, 20, 30, 45];

  @override
  void dispose() {
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedReminder();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Khi app quay lại foreground, tính lại ngay lập tức từ đồng hồ thực thay
    // vì chờ tick tiếp theo của Timer (Timer có thể đã bị hệ điều hành tạm
    // dừng trong lúc app ở nền).
    if (state == AppLifecycleState.resumed && _endAt != null) {
      _syncWithRealNextFireTime();
    } else if (state == AppLifecycleState.paused && _endAt != null) {
      // Timer.periodic sẽ ngừng tick khi app xuống nền -> đổi thông báo ghim
      // sang giờ hẹn CỐ ĐỊNH thay vì để lại con số mm:ss "đứng hình" gây hiểu
      // lầm app bị treo. Báo thức hệ thống (đã lên lịch từ trước) không phụ
      // thuộc vào việc này, vẫn tự bắn đúng giờ.
      final strings = context.read<LanguageProvider>().strings;
      NotificationService.instance.showStaticOngoingUntil(
        endAt: _endAt!,
        title: strings.breakNotificationTitle,
        untilPrefix: strings.breakNotificationUntil,
      );
    }
  }

  void _recomputeFromEndAt() {
    if (_endAt == null) return;
    final remaining = _endAt!.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _countdownTimer?.cancel();
      setState(() {
        _secondsRemaining = 0;
        _breakPromptShowing = true;
      });
    } else {
      setState(() => _secondsRemaining = remaining);
    }
  }

  // Báo thức lặp thật (chạy hoàn toàn native, xem notification_service.dart)
  // có thể đã bắn thêm 1 hoặc nhiều chu kỳ trong lúc app ở nền/đóng — nếu
  // chỉ tính từ `_endAt` cũ (chốt lúc Start lần đầu) thì UI trong app sẽ
  // hiển thị SAI, lệch hẳn với báo thức thật đang chạy. Tính lại mốc giờ kế
  // tiếp THẬT (dựa trên mốc bắt đầu + interval) để đồng bộ đúng.
  Future<void> _syncWithRealNextFireTime() async {
    final realNext = await NotificationService.instance.getNextRepeatingFireAt();
    if (!mounted) return;
    if (realNext != null) {
      _endAt = realNext;
    }
    _recomputeFromEndAt();
    if (_secondsRemaining > 0) {
      _updateOngoingNotification();
    }
  }

  Future<void> _loadSavedReminder() async {
    final reminder = context.read<ReminderProvider>();
    final endAt = await DeviceDataService.instance.loadBreakReminderEnd();
    final interval = await DeviceDataService.instance.loadBreakReminderIntervalMinutes();
    if (endAt != null && interval != null) {
      final now = DateTime.now();
      final secondsLeft = endAt.difference(now).inSeconds;
      _endAt = endAt;
      if (secondsLeft > 0) {
        reminder.toggleEyeBreakReminder(true);
        _secondsRemaining = secondsLeft;
        _scheduleRepeatingAlarm(interval);
        _startCountdown(reminder);
        _updateOngoingNotification();
      } else {
        _secondsRemaining = 0;
        _breakPromptShowing = true;
      }
      setState(() {});
    }
  }

  void _startReminder(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    final endAt = DateTime.now().add(Duration(minutes: reminder.reminderMinutes));
    _endAt = endAt;
    _secondsRemaining = reminder.reminderMinutes * 60;
    reminder.toggleEyeBreakReminder(true);
    _saveReminderEnd(reminder.reminderMinutes, endAt);
    _scheduleRepeatingAlarm(reminder.reminderMinutes);
    _startCountdown(reminder);
    _updateOngoingNotification();
    setState(() {});
  }

  // Cập nhật nội dung thông báo ghim với số giây còn lại hiện tại.
  void _updateOngoingNotification() {
    if (!mounted) return;
    final strings = context.read<LanguageProvider>().strings;
    NotificationService.instance.updateOngoingCountdown(
      secondsRemaining: _secondsRemaining,
      title: strings.breakNotificationTitle,
      remainingSuffix: strings.breakNotificationRemaining,
      endAt: _endAt,
    );
  }

  // Lên lịch báo thức LẶP LẠI mỗi `intervalMinutes` phút — hệ điều hành tự
  // bắn (và tự lặp lại) kể cả khi app đang ở nền hoặc đã bị đóng hẳn, không
  // phụ thuộc vào Timer trong bộ nhớ. Đây là NGUỒN DUY NHẤT bắn thông báo
  // hết-giờ-nghỉ-mắt thật sự — cứ thế lặp lại cho tới khi người dùng vào app
  // và bấm "Tắt" (xem _stopReminder), không cần app phải luôn mở.
  void _scheduleRepeatingAlarm(int intervalMinutes) {
    final strings = context.read<LanguageProvider>().strings;
    NotificationService.instance.scheduleRepeatingBreakAlarm(
      intervalMinutes: intervalMinutes,
      title: strings.eyeBreakTimeUp,
      body: strings.eyeBreakLookAway,
      ongoingTitle: strings.breakNotificationTitle,
      ongoingRemainingSuffix: strings.breakNotificationUntil,
    );
  }

  void _startCountdown(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // QUAN TRỌNG: tính lại từ _endAt (đồng hồ thực) mỗi tick, KHÔNG đơn
      // thuần trừ 1 mỗi lần tick — nếu Timer bị hệ điều hành tạm dừng một lúc
      // (app chạy nền) rồi mở lại, tick tiếp theo sẽ tự nhảy về đúng giá trị
      // thực tế thay vì tiếp tục đếm từ chỗ "đóng băng" trước đó.
      if (_endAt == null) return;
      final remaining = _endAt!.difference(DateTime.now()).inSeconds;
      setState(() {
        _secondsRemaining = remaining;
        if (remaining <= 0) {
          _breakPromptShowing = true;
          _countdownTimer?.cancel();
          // KHÔNG tự bắn thêm thông báo tay ở đây nữa: báo thức LẶP LẠI
          // (scheduleRepeatingBreakAlarm) đã là nguồn duy nhất bắn thông
          // báo hết-giờ-nghỉ-mắt, chạy độc lập trong isolate nền của hệ
          // điều hành — kể cả khi Timer này đang chạy vì app đang mở. Tự
          // bắn thêm ở đây từng gây trùng thông báo/rung 2 lần liền nhau.
          // Màn hình "confirm break" ở đây chỉ để GHI NHẬN lần nghỉ vào
          // Habits khi người dùng đang mở app đúng lúc hết giờ.
        }
      });
      if (_secondsRemaining > 0) {
        _updateOngoingNotification();
      }
    });
  }

  void _stopReminder(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    _endAt = null;
    reminder.toggleEyeBreakReminder(false);
    DeviceDataService.instance.clearBreakReminderEnd();
    // Đây là cách DUY NHẤT vòng lặp nhắc nghỉ mắt dừng lại — huỷ báo thức
    // LẶP LẠI đã đăng ký với hệ điều hành, nếu không nó sẽ tiếp tục tự bắn
    // mỗi `intervalMinutes` phút vô thời hạn kể cả khi app đã đóng.
    NotificationService.instance.cancelRepeatingBreakAlarm();
    setState(() {
      _secondsRemaining = 0;
      _breakPromptShowing = false;
    });
  }

  Future<void> _confirmBreakTaken(ReminderProvider reminder) async {
    await context.read<HabitProvider>().recordEyeBreak();
    if (!mounted) return;
    setState(() => _breakPromptShowing = false);
    // Tự động bắt đầu chu kỳ đếm ngược tiếp theo.
    _startReminder(reminder);
  }

  Future<void> _saveReminderEnd(int intervalMinutes, DateTime endAt) async {
    await DeviceDataService.instance.saveBreakReminderEnd(endAt, intervalMinutes);
  }

  void _dismissPrompt(ReminderProvider reminder) {
    setState(() => _breakPromptShowing = false);
    _startReminder(reminder);
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<ReminderProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

    if (_breakPromptShowing) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: language.isVietnamese ? 'Quay lại' : 'Back',
          ),
        ),
        body: SafeArea(child: _BreakPromptView(
          onDone: () => _confirmBreakTaken(reminder),
          onSkip: () => _dismissPrompt(reminder),
        )),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: language.isVietnamese ? 'Quay lại' : 'Back',
        ),
        title: Text(strings.eyeBreakTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.eyeBreakTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(strings.eyeBreakSubtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              SectionCard(
                child: Column(
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: reminder.isEyeBreakReminderActive && reminder.reminderMinutes > 0
                                  ? _secondsRemaining / (reminder.reminderMinutes * 60)
                                  : 1,
                              strokeWidth: 10,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(AppColors.testAccent),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                reminder.isEyeBreakReminderActive
                                    ? _formatCountdown(_secondsRemaining)
                                    : '--:--',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              Text(
                                reminder.isEyeBreakReminderActive
                                    ? strings.eyeBreakNextIn
                                    : strings.eyeBreakStart,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!reminder.isEyeBreakReminderActive) ...[
                      Text(strings.eyeBreakIntervalLabel, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _intervalOptions.map((minutes) {
                          final selected = reminder.reminderMinutes == minutes;
                          return ChoiceChip(
                            label: Text('$minutes ${strings.vi ? "phút" : "min"}'),
                            selected: selected,
                            onSelected: (_) => reminder.setReminderMinutes(minutes),
                            selectedColor: AppColors.testAccent.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: selected ? AppColors.testAccent : null,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: reminder.isEyeBreakReminderActive
                              ? AppColors.error
                              : AppColors.testAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => reminder.isEyeBreakReminderActive
                            ? _stopReminder(reminder)
                            : _startReminder(reminder),
                        child: Text(
                          reminder.isEyeBreakReminderActive ? strings.eyeBreakStop : strings.eyeBreakStart,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: SettingsToggleTile(
                  title: strings.autoDetectEyeBreakTitle,
                  description: strings.autoDetectEyeBreakDescription,
                  value: reminder.autoDetectEyeBreaks,
                  onChanged: (value) => reminder.setAutoDetectEyeBreaks(value),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.testAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('👁️', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.eyeBreakTodayCount, style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            '${context.watch<HabitProvider>().eyeBreaksTakenToday}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.testAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakPromptView extends StatefulWidget {
  const _BreakPromptView({required this.onDone, required this.onSkip});

  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  State<_BreakPromptView> createState() => _BreakPromptViewState();
}

class _BreakPromptViewState extends State<_BreakPromptView> {
  int _secondsLeft = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Container(
      color: AppColors.testAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            strings.eyeBreakTimeUp,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.eyeBreakLookAway,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '$_secondsLeft',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.testAccent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.testAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.onDone,
              child: Text(strings.eyeBreakDone),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onSkip,
            child: Text(strings.eyeBreakSkip),
          ),
        ],
      ),
    );
  }
}