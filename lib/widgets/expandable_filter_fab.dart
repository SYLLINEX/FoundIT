import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';

class ExpandableFilterFab extends StatefulWidget {
  final List<String> categories;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;

  const ExpandableFilterFab({
    super.key,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
  });

  @override
  State<ExpandableFilterFab> createState() => _ExpandableFilterFabState();
}

class _ExpandableFilterFabState extends State<ExpandableFilterFab> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 56,
      width: _isExpanded
          ? 260
          : 56, // Expand wider to accommodate chips clearly
      decoration: BoxDecoration(
        color: AppColors.nightfall,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: _isExpanded
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    reverse:
                        true, // Aligns content dynamically from the trailing anchor
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: widget.categories.asMap().entries.map((e) {
                          final isSelected =
                              widget.selectedCategoryIndex == e.key;
                          return GestureDetector(
                            onTap: () {
                              widget.onCategorySelected(e.key);
                              setState(() => _isExpanded = false);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? null
                                    : Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                e.value.replaceAll(' Items', ''),
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.nightfall
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              height: 56,
              width: 56,
              color: Colors.transparent,
              child: Icon(
                _isExpanded
                    ? PhosphorIconsRegular.x
                    : PhosphorIconsRegular.funnel,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
