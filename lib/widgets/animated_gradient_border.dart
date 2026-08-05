import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Khung viền gradient "sống" — màu viền đổi liên tục nhưng SMOOTH, dao động
/// quanh [baseColor] trong biên độ [hueRange] độ (không nhảy hẳn sang tông
/// màu khác). Dùng cho các thẻ muốn nổi bật (bậc xếp hạng hiện tại, thẻ
/// "hạng của bạn"...) mà vẫn tôn trọng màu accent người dùng chọn trong Cài
/// đặt — nếu accent là xanh dương thì viền chỉ lượn trong dải xanh dương,
/// không đổi sang đỏ/tím.
///
/// Cách hoạt động: 1 AnimationController lặp vô hạn, mỗi frame tính lại 5
/// điểm màu (điểm đầu = điểm cuối để tránh "giật" khi nối vòng) bằng hàm sin
/// dao động hue quanh baseColor, dùng làm SweepGradient rồi xoay dần — vừa
/// đổi màu vừa như "chảy" quanh viền, mượt vì luôn nội suy liên tục theo t.
class AnimatedGradientBorder extends StatefulWidget {
  const AnimatedGradientBorder({
    super.key,
    required this.child,
    required this.baseColor,
    this.borderRadius = 20,
    this.borderWidth = 2.5,
    this.hueRange = 26,
    this.duration = const Duration(seconds: 5),
    this.innerColor,
    this.innerPadding,
  });

  final Widget child;
  final Color baseColor;
  final double borderRadius;
  final double borderWidth;

  /// Biên độ dao động sắc độ (hue) tính bằng độ quanh [baseColor].
  final double hueRange;
  final Duration duration;

  /// Màu nền phần bên trong viền — mặc định lấy màu surface của theme hiện
  /// tại (tự đổi theo sáng/tối, không hardcode để không phá dark mode).
  final Color? innerColor;
  final EdgeInsetsGeometry? innerPadding;

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorAt(double t, double phaseOffset) {
    final hsl = HSLColor.fromColor(widget.baseColor);
    // sin cho ra dao động mượt trong [-1, 1] — nhân với hueRange để hue chỉ
    // lượn quanh gốc trong 1 khoảng cố định, không bao giờ đi hết vòng màu.
    final wave = math.sin(2 * math.pi * (t + phaseOffset));
    var hue = (hsl.hue + wave * widget.hueRange) % 360;
    if (hue < 0) hue += 360;
    final lightness = (hsl.lightness + wave * 0.10).clamp(0.20, 0.78);
    final saturation = (hsl.saturation + 0.05).clamp(0.0, 1.0);
    return hsl.withHue(hue).withLightness(lightness).withSaturation(saturation).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final innerColor = widget.innerColor ?? Theme.of(context).colorScheme.surface;
    final innerRadius = (widget.borderRadius - widget.borderWidth).clamp(0.0, widget.borderRadius);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Điểm đầu == điểm cuối (phase 0 và phase 1) để vòng lặp không bị
        // giật/gãy màu tại điểm nối.
        final colors = [
          _colorAt(t, 0.0),
          _colorAt(t, 0.25),
          _colorAt(t, 0.5),
          _colorAt(t, 0.75),
          _colorAt(t, 1.0),
        ];
        return Container(
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              colors: colors,
              transform: GradientRotation(2 * math.pi * t),
            ),
            boxShadow: [
              BoxShadow(
                color: _colorAt(t, 0.0).withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Container(
            padding: widget.innerPadding,
            decoration: BoxDecoration(
              color: innerColor,
              borderRadius: BorderRadius.circular(innerRadius),
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
