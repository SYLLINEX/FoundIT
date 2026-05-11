import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(message, 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), height: 1.4)
          ),
        ],
      ),
    );
  }
}
