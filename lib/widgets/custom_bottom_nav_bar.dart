import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final VoidCallback onAddTapped;

  // Optional GlobalKeys used by the feature tour to locate spotlight targets
  final GlobalKey? homeTabKey;
  final GlobalKey? mapTabKey;
  final GlobalKey? fabKey;
  final GlobalKey? reportsTabKey;
  final GlobalKey? profileTabKey;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onAddTapped,
    this.homeTabKey,
    this.mapTabKey,
    this.fabKey,
    this.reportsTabKey,
    this.profileTabKey,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  final List<String> _labels = ['Home', 'Map', 'Reports', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 12 + bottomInset,
      left: 16,
      right: 16,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 76, // Reduced from 92
            decoration: BoxDecoration(
              color: AppColors.nightfall,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(
                    icon: PhosphorIconsRegular.house,
                    activeIcon: PhosphorIconsRegular.house,
                    index: 0,
                    itemKey: widget.homeTabKey,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: PhosphorIconsRegular.mapTrifold,
                    activeIcon: PhosphorIconsRegular.mapTrifold,
                    index: 1,
                    itemKey: widget.mapTabKey,
                  ),
                ),
                const Spacer(),
                Expanded(
                  child: _buildNavItem(
                    icon: PhosphorIconsRegular.clipboardText,
                    activeIcon: PhosphorIconsRegular.clipboardText,
                    index: 2,
                    itemKey: widget.reportsTabKey,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: PhosphorIconsRegular.user,
                    activeIcon: PhosphorIconsRegular.user,
                    index: 3,
                    itemKey: widget.profileTabKey,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -16,
            child: GestureDetector(
              onTap: widget.onAddTapped,
              child: Container(
                key: widget.fabKey,
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.deepLavender,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.silverShadow.withValues(alpha: 0.95),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(PhosphorIconsRegular.plus, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required int index,
    GlobalKey? itemKey,
  }) {
    final bool isSelected = widget.selectedIndex == index;

    return GestureDetector(
      key: itemKey,
      onTap: () => widget.onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey<bool>(isSelected),
                size: 20, // Reduced from 22
                color: isSelected
                    ? Colors.white
                    : AppColors.silverShadow.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 2), // Reduced from 4
            Text(
              _labels[index],
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppColors.silverShadow.withValues(alpha: 0.65),
                fontSize: 10, // Reduced from 11
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
