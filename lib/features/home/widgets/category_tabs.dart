import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/theme/app_colors.dart';

class CategoryTabs extends StatelessWidget {
  final List<String> categories;
  final Function(int) onTabSelected;
  final int selectedIndex;

  const CategoryTabs({
    super.key,
    required this.categories,
    required this.onTabSelected,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Filter items',
      initialValue: selectedIndex,
      onSelected: onTabSelected,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) {
        return categories.asMap().entries.map((entry) {
          final idx = entry.key;
          final name = entry.value;
          final isSelected = idx == selectedIndex;
          return PopupMenuItem<int>(
            value: idx,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: AppColors.nightfall,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    PhosphorIconsRegular.check,
                    color: AppColors.nightfall,
                    size: 18,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          PhosphorIconsRegular.slidersHorizontal, // Using a more modern filter icon
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
