import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/language_provider.dart';
import '../theme/app_colors.dart';

// Địa chỉ email nhận feedback — đổi thành email hỗ trợ thật của bạn.
const String _kSupportEmail = 'eyecareai.app@gmail.com';

class FeedbackForm extends StatefulWidget {
  const FeedbackForm({super.key});

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _controller = TextEditingController();
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // App không có backend riêng để nhận feedback, nên thay vì giả vờ "gửi
  // thành công" (TODO cũ), mình mở thẳng ứng dụng Gmail/Email của máy với
  // nội dung đã điền sẵn (rating + góp ý) — người dùng chỉ cần bấm Gửi.
  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty && _rating == 0) return;
    setState(() => _submitting = true);
    final strings = context.read<LanguageProvider>().strings;

    final stars = _rating > 0 ? '${'⭐' * _rating} ($_rating/5)' : (strings.vi ? 'Chưa chấm điểm' : 'No rating');
    final body = Uri.encodeComponent(
      '${strings.vi ? "Đánh giá" : "Rating"}: $stars\n\n'
      '${strings.vi ? "Góp ý" : "Feedback"}:\n${_controller.text.trim()}',
    );
    final subject = Uri.encodeComponent(strings.vi ? 'Góp ý EyeCare AI' : 'EyeCare AI Feedback');
    final mailUri = Uri.parse('mailto:$_kSupportEmail?subject=$subject&body=$body');

    bool opened = false;
    try {
      opened = await launchUrl(mailUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (opened) {
      _controller.clear();
      setState(() => _rating = 0);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.feedbackNoEmailApp)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          minLines: 4,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: strings.feedbackHint,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _rating;
            return IconButton(
              onPressed: () => setState(() => _rating = i + 1),
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                color: AppColors.warning,
                size: 30,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(strings.submitFeedback),
          ),
        ),
      ],
    );
  }
}
