import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'dart:math' as math;
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

class _ExpandableFilterFabState extends State<ExpandableFilterFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  Widget _buildFilterItem(int index, String title, bool isSelected) {
    final int count = widget.categories.length;
    // Avoid division by zero
    final double fraction = count > 1 ? index / (count - 1) : 0.0;
    // Angle from -pi/2 (up) to -pi (left), spanning a quarter circle (90 degrees).
    final double angle = -math.pi / 2 - (fraction * math.pi / 2);
    // Dynamically calculate radius to maintain consistent aesthetic without cramping
    int maxLength = widget.categories.fold(0, (max, cat) {
      final len = cat.replaceAll(' Items', '').length;
      return len > max ? len : max;
    });

    double calculatedRadius = 80.0;
    if (count >= 3) {
      calculatedRadius += (count - 3) * 15.0;
    }
    if (maxLength > 6) {
      calculatedRadius += (maxLength - 6) * 5.0;
    }
    final double radius = calculatedRadius;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final double value = _expandAnimation.value;
        return FractionalTranslation(
          // Shift the item so its center aligns exactly with the bottom-right anchor
          translation: const Offset(0.5, 0.5),
          child: Transform.translate(
            offset: Offset(
              radius * math.cos(angle) * value,
              radius * math.sin(angle) * value,
            ),
            child: Transform.scale(
              scale: value == 0 ? 0.0 : value.clamp(0.0, 1.0),
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          widget.onCategorySelected(index);
          _toggleMenu();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.nightfall : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.grey.shade300,
            ),
          ),
          child: Text(
            title.replaceAll(' Items', ''),
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.nightfall,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: 'filter_fab',
      onTapOutside: (event) {
        if (_isExpanded) {
          _toggleMenu();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final bool isOpen = _controller.value > 0.0;
          return SizedBox(
            width: isOpen ? 300 : 56,
            height: isOpen ? 260 : 56,
            child: Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: [
                // Tap occasionally inside the 300x260 box but outside items -> close
                if (isOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleMenu,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                // Items
                ...List.generate(widget.categories.length, (index) {
                  return Positioned(
                    // Center of the main 56x56 FAB is 28px from right and bottom
                    right: 28,
                    bottom: 28,
                    child: _buildFilterItem(
                      index,
                      widget.categories[index],
                      widget.selectedCategoryIndex == index,
                    ),
                  );
                }),
                // Main Toggle FAB
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _toggleMenu,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 56,
                      width: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.nightfall,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: RotationTransition(
                          turns: Tween<double>(
                            begin: 0.0,
                            end: 0.125,
                          ).animate(_expandAnimation),
                          child: Icon(
                            _isExpanded
                                ? PhosphorIconsRegular.plus
                                : PhosphorIconsRegular.funnel,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
