import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../widgets/monthly_app_usage_card.dart';

/// Màn "Thống kê tháng": thời gian sử dụng ứng dụng theo tháng.
class MonthlyUsageScreen extends StatelessWidget {
  const MonthlyUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: vi ? 'Quay lại' : 'Back',
        ),
        title: Text(vi ? 'Thống kê tháng' : 'Monthly stats'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vi ? 'Thời gian sử dụng ứng dụng theo tháng' : 'App usage time by month',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const MonthlyAppUsageCard(),
            ],
          ),
        ),
      ),
    );
  }
}