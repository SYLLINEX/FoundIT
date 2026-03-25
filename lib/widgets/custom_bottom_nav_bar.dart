import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final VoidCallback onAddTapped;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onAddTapped,
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
      bottom: 14 + bottomInset,
      left: 20,
      right: 20,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.nightfall,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    index: 0,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map,
                    index: 1,
                  ),
                ),
                const SizedBox(width: 72),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.assignment_outlined,
                    activeIcon: Icons.assignment,
                    index: 2,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person,
                    index: 3,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -20,
            child: GestureDetector(
              onTap: widget.onAddTapped,
              child: Container(
                height: 54,
                width: 54,
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
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
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
  }) {
    final bool isSelected = widget.selectedIndex == index;

    return GestureDetector(
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
                size: 22,
                color: isSelected
                    ? Colors.white
                    : AppColors.silverShadow.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[index],
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppColors.silverShadow.withValues(alpha: 0.65),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
