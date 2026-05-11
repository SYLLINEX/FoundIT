import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A thin wrapper around [Shimmer.fromColors] that automatically uses
/// theme-aware colours — dark mode gets dark skeleton tones instead of
/// the light-mode grey[300]/grey[100] defaults.
class ThemeAwareShimmer extends StatelessWidget {
  final Widget child;

  const ThemeAwareShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2C2A3A) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3A3850) : const Color(0xFFF5F5F5),
      child: child,
    );
  }
}
