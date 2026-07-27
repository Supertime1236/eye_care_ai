import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_colors.dart';

List<MapEntry<String, String>> _faqs(bool vi) => [
      MapEntry(
        vi ? 'Eye Care AI hoạt động như thế nào?' : 'How does Eye Care AI work?',
        vi
            ? 'Ứng dụng dùng camera thiết bị và thói quen sử dụng để ước tính thời gian màn hình, tần suất chớp mắt, khoảng cách nhìn, từ đó gợi ý nghỉ ngơi và bài tập phù hợp.'
            : 'It uses your device camera and usage patterns to estimate screen time, blink rate, and distance, then suggests breaks and exercises tailored to your habits.',
      ),
      MapEntry(
        vi ? 'Thời gian màn hình được tính như thế nào?' : 'How is screen time calculated?',
        vi
            ? 'Chúng tôi theo dõi thời gian sử dụng ứng dụng ở chế độ nền trước, kết hợp dữ liệu cảm biến để ước tính thời gian nhìn màn hình chủ động so với thời gian rảnh.'
            : 'We track foreground app usage on your device and combine it with sensor data to estimate active screen-viewing time versus idle time.',
      ),
      MapEntry(
        vi ? 'Vì sao tính năng phát hiện ngoài trời không hoạt động?' : "Why doesn't outdoor detection work?",
        vi
            ? 'Tính năng này dựa vào ánh sáng môi trường và cảm biến vị trí. Hãy đảm bảo đã bật quyền vị trí, chuyển động và bạn ở ngoài trời ít nhất một phút.'
            : 'Outdoor detection relies on ambient light and location sensors. Make sure location and motion permissions are enabled and you are outside for at least a minute.',
      ),
      MapEntry(
        vi ? 'AI tạo gợi ý như thế nào?' : 'How does AI generate recommendations?',
        vi
            ? 'Gợi ý được tạo dựa trên thói quen bạn đã ghi, tần suất nghỉ ngơi và (nếu bật) phân tích AI cá nhân hóa dựa trên thói quen sử dụng.'
            : 'Recommendations are generated from your logged habits, break frequency, and (if enabled) personalized AI analysis of your usage patterns.',
      ),
      MapEntry(
        vi ? 'Làm sao để đặt lại tiến trình?' : 'How do I reset my progress?',
        vi
            ? 'Vào Cài đặt > Cài đặt thêm > Quyền riêng tư & Bảo mật > Quản lý dữ liệu > Xóa toàn bộ dữ liệu cục bộ. Thao tác này đặt lại tiến trình trên thiết bị mà không xóa tài khoản.'
            : 'Go to Settings > More > Privacy & Security > Data Management > Delete All Local Data. This resets progress on this device without deleting your account.',
      ),
    ];

/// Accordion chỉ mở một mục tại một thời điểm.
class FaqAccordion extends StatefulWidget {
  const FaqAccordion({super.key});

  @override
  State<FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<FaqAccordion> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    final faqs = _faqs(vi);
    return Column(
      children: [
        for (int i = 0; i < faqs.length; i++) ...[
          _FaqItem(
            question: faqs[i].key,
            answer: faqs[i].value,
            expanded: _openIndex == i,
            onTap: () => setState(() => _openIndex = _openIndex == i ? null : i),
          ),
          if (i != faqs.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: _duration,
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
              AnimatedSize(
                duration: _duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedCrossFade(
                  duration: _duration,
                  crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      answer,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
