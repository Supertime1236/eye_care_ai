import 'package:flutter/material.dart';

class IPhoneFrame extends StatelessWidget {
  const IPhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            final frameWidth = (maxWidth * 0.92).clamp(320.0, 420.0);
            final frameHeight = (maxHeight * 0.94).clamp(640.0, 860.0);

            return Container(
              width: frameWidth,
              height: frameHeight,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D3A),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: const Color(0xFF3D3D4A), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(38),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _StatusBar(width: frameWidth - 24),
                    Expanded(child: child),
                    _HomeIndicator(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Container(
      height: 44,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            child: Container(
              width: 120,
              height: 28,
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '9:41',
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.signal_cellular_4_bar, size: 16, color: fg),
                    const SizedBox(width: 4),
                    Icon(Icons.wifi, size: 16, color: fg),
                    const SizedBox(width: 4),
                    Icon(Icons.battery_full, size: 16, color: fg),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: Container(
        width: 120,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white38
              : Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
