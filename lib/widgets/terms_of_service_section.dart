import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../screens/document_viewer_screen.dart';
import '../theme/app_colors.dart';

class _TermsDoc {
  const _TermsDoc(this.title, this.icon, this.body);
  final String title;
  final IconData icon;
  final String body;
}

List<_TermsDoc> _docs(bool vi) => [
      _TermsDoc(
        vi ? 'Chính sách sử dụng ứng dụng' : 'App Usage Policy',
        Icons.description_outlined,
        vi
            ? 'Nội dung tạm thời — thay bằng nội dung Chính sách sử dụng ứng dụng thật.'
            : 'Placeholder body — replace with your real App Usage Policy text.',
      ),
      _TermsDoc(
        vi ? 'Trách nhiệm người dùng' : 'User Responsibilities',
        Icons.assignment_ind_outlined,
        vi
            ? 'Nội dung tạm thời — thay bằng nội dung Trách nhiệm người dùng thật.'
            : 'Placeholder body — replace with your real User Responsibilities text.',
      ),
      _TermsDoc(
        vi ? 'Tuyên bố miễn trừ AI' : 'AI Disclaimer',
        Icons.smart_toy_outlined,
        vi
            ? 'Nội dung tạm thời — thay bằng nội dung Tuyên bố miễn trừ AI thật.'
            : 'Placeholder body — replace with your real AI Disclaimer text.',
      ),
      _TermsDoc(
        vi ? 'Tuyên bố miễn trừ y tế' : 'Medical Disclaimer',
        Icons.local_hospital_outlined,
        vi
            ? 'Nội dung tạm thời — thay bằng nội dung Tuyên bố miễn trừ y tế thật.'
            : 'Placeholder body — replace with your real Medical Disclaimer text.',
      ),
      _TermsDoc(
        vi ? 'Chính sách bảo vệ dữ liệu' : 'Data Protection Policy',
        Icons.shield_outlined,
        vi
            ? 'Nội dung tạm thời — thay bằng nội dung Chính sách bảo vệ dữ liệu thật.'
            : 'Placeholder body — replace with your real Data Protection Policy text.',
      ),
      _TermsDoc(
        vi ? 'Giấy phép mã nguồn mở' : 'Open Source Licenses',
        Icons.code_rounded,
        vi
            ? 'Liệt kê các thư viện mã nguồn mở và giấy phép tại đây, hoặc nối thẻ này với showLicensePage(context: context).'
            : 'List your open-source packages and licenses here, or wire this card to showLicensePage(context: context).',
      ),
    ];

class TermsOfServiceSection extends StatelessWidget {
  const TermsOfServiceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final docs = _docs(strings.vi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final doc in docs) ...[
          _DocCard(doc: doc),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              Text(strings.termsVersion, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(strings.termsLastUpdated, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc});
  final _TermsDoc doc;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DocumentViewerScreen(title: doc.title, body: doc.body)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(doc.icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
