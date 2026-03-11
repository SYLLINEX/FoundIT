import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CategoryTabs extends StatefulWidget {
  final List<String> categories;
  final Function(int) onTabSelected;

  const CategoryTabs({
    super.key,
    required this.categories,
    required this.onTabSelected,
  });

  @override
  State<CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends State<CategoryTabs> {
  int _selectedIndex = 1; // Default to 'Lost Items' based on mockup

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.categories.asMap().entries.map((entry) {
          int idx = entry.key;
          String name = entry.value;
          bool isSelected = idx == _selectedIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(name),
              selected: isSelected,
              onSelected: (bool selected) {
                if (selected) {
                  setState(() {
                    _selectedIndex = idx;
                  });
                  widget.onTabSelected(idx);
                }
              },
              backgroundColor: AppColors.mist,
              selectedColor: AppColors.nightfall,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.nightfall,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
        }).toList(),
      ),
    );
  }
}
