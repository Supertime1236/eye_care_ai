import 'package:flutter/material.dart';

/// Render text with lightweight inline Markdown formatting:
/// **bold**, *italic* (or _italic_), and `code`.
///
/// Trợ lý AI trả lời dạng text thuần theo chuẩn Markdown rút gọn (dùng dấu
/// * để in đậm/in nghiêng). Widget này parse thủ công (không cần thêm
/// package flutter_markdown) và dựng thành RichText để hiện đúng định dạng
/// đậm/nghiêng thay vì hiện nguyên dấu `**`/`*` thô trên màn hình.
class FormattedChatText extends StatelessWidget {
  const FormattedChatText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: style,
        children: _parseInline(text, style),
      ),
    );
  }

  static List<InlineSpan> _parseInline(String input, TextStyle base) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString()));
        buffer.clear();
      }
    }

    var i = 0;
    while (i < input.length) {
      // **bold**
      if (_matches(input, i, '**')) {
        final end = input.indexOf('**', i + 2);
        if (end != -1 && end > i + 2) {
          flush();
          spans.add(
            TextSpan(
              text: input.substring(i + 2, end),
              style: base.copyWith(fontWeight: FontWeight.bold),
            ),
          );
          i = end + 2;
          continue;
        }
      }
      // `code`
      if (input[i] == '`') {
        final end = input.indexOf('`', i + 1);
        if (end != -1 && end > i + 1) {
          flush();
          spans.add(
            TextSpan(
              text: input.substring(i + 1, end),
              style: base.copyWith(
                fontFamily: 'monospace',
                backgroundColor: base.color?.withValues(alpha: 0.08),
              ),
            ),
          );
          i = end + 1;
          continue;
        }
      }
      // *italic* or _italic_ (single marker, not part of ** already handled above)
      if ((input[i] == '*' || input[i] == '_')) {
        final marker = input[i];
        final end = input.indexOf(marker, i + 1);
        if (end != -1 && end > i + 1) {
          final inner = input.substring(i + 1, end);
          // Avoid treating a stray "**" leftover or empty match as italic.
          if (inner.isNotEmpty && !inner.contains('\n')) {
            flush();
            spans.add(
              TextSpan(
                text: inner,
                style: base.copyWith(fontStyle: FontStyle.italic),
              ),
            );
            i = end + 1;
            continue;
          }
        }
      }
      buffer.write(input[i]);
      i++;
    }
    flush();
    return spans;
  }

  static bool _matches(String input, int index, String token) {
    if (index + token.length > input.length) return false;
    return input.substring(index, index + token.length) == token;
  }
}
