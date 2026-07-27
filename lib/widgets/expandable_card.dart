import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'shared_widgets.dart';

/// Thẻ "kiểu iOS" có thể mở rộng/thu gọn.
/// Chạm vào phần tiêu đề để mở/thu gọn [child] với hiệu ứng
/// AnimatedSize + fade, mũi tên bên phải xoay 90°.
class ExpandableCard extends StatefulWidget {
  const ExpandableCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<ExpandableCard> createState() => ExpandableCardState();
}

class ExpandableCardState extends State<ExpandableCard> {
  late bool _expanded = widget.initiallyExpanded;

  static const _duration = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;

  void _toggle() => setState(() => _expanded = !_expanded);

  /// Cho phép màn hình cha mở thẻ này theo chương trình (ví dụ điều hướng
  /// trực tiếp tới mục "Bảo mật" từ trang Settings chính).
  void expand() {
    if (!_expanded) setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.iconColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _toggle,
                splashColor: iconColor.withValues(alpha: 0.08),
                highlightColor: iconColor.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (widget.subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  widget.subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0.0,
                        duration: _duration,
                        curve: _curve,
                        child: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: _duration,
              curve: _curve,
              alignment: Alignment.topCenter,
              child: AnimatedCrossFade(
                duration: _duration,
                sizeCurve: _curve,
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
