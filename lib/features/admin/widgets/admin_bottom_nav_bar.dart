import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AdminBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AdminBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        height: 65,
        decoration: BoxDecoration(
          color: AppColors.nightfall,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: AppColors.nightfall.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.dashboard_rounded, 0),
            _buildNavItem(Icons.verified_outlined, 1),
            _buildNavItem(Icons.map_outlined, 2),
            _buildNavItem(Icons.analytics_outlined, 3),
            _buildNavItem(Icons.person_outline, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white60,
          size: 26,
        ),
      ),
    );
  }
}
