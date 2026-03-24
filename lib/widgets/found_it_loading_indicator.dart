import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../core/theme/app_colors.dart';

class FoundItLoadingIndicator extends StatelessWidget {
  final double size;
  final Color color;

  const FoundItLoadingIndicator({
    super.key,
    this.size = 34,
    this.color = AppColors.deepLavender,
  });

  @override
  Widget build(BuildContext context) {
    return SpinKitWanderingCubes(color: color, size: size);
  }
}
