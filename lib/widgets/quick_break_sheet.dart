import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auto_break_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';

/// Nút "Nghỉ mắt 20 giây ngay" ở Trang chủ: 1 chạm là bắt đầu đếm 20 giây nhìn
/// xa, hết giờ tự tính 1 lần nghỉ mắt — không phải chờ thông báo nhắc.
class QuickBreakButton extends StatelessWidget {
  const QuickBreakButton({super.key});

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: () => showQuickBreakSheet(context),
          icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
          label: Text(vi ? 'Nghỉ mắt 20 giây ngay' : 'Rest your eyes for 20 seconds'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

Future<void> showQuickBreakSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _QuickBreakSheet(),
  );
}

class _QuickBreakSheet extends StatefulWidget {
  const _QuickBreakSheet();

  @override
  State<_QuickBreakSheet> createState() => _QuickBreakSheetState();
}

class _QuickBreakSheetState extends State<_QuickBreakSheet> {
  static const _total = 20;

  late final HabitProvider _habit;
  late final AutoBreakProvider _auto;
  Timer? _timer;
  int _left = _total;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Lấy provider ngay từ đầu để không dùng BuildContext sau các khoảng async.
    _habit = context.read<HabitProvider>();
    _auto = context.read<AutoBreakProvider>();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_left <= 1) {
      _timer?.cancel();
      setState(() {
        _left = 0;
        _done = true;
      });
      HapticFeedback.mediumImpact();
      await _habit.recordEyeBreak();
      // Nếu đang bật "Tự động nhắc nghỉ mắt" thì bắt đầu chu kỳ mới từ bây giờ.
      if (_auto.enabled) await _auto.confirmBreakManually();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    setState(() => _left--);
  }

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _done
                  ? (vi ? 'Xong rồi!' : 'Done!')
                  : (vi ? 'Nhìn ra xa khoảng 6 mét' : 'Look at something about 6 m away'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _done
                  ? (vi ? 'Đã tính 1 lần nghỉ mắt cho hôm nay.' : 'Counted as 1 eye break today.')
                  : (vi
                      ? 'Nhìn qua cửa sổ hoặc một vật ở xa, chớp mắt vài lần.'
                      : 'Look out of a window or at something far away, and blink a few times.'),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 130,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: _done ? 1 : (_total - _left) / _total,
                      strokeWidth: 9,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: AlwaysStoppedAnimation(_done ? AppColors.success : primary),
                    ),
                  ),
                  _done
                      ? const Icon(Icons.check_rounded, size: 52, color: AppColors.success)
                      : Text(
                          '$_left',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (!_done)
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(vi ? 'Huỷ' : 'Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}