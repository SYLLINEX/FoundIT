import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CustomBottomNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
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
                _buildNavItem(Icons.home_filled, 0),
                _buildNavItem(Icons.map_outlined, 1),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(Icons.checklist_rtl_rounded, 2),
                _buildNavItem(Icons.person_outline, 3),
              ],
            ),
          ),
          Positioned(
            top: -24,
            child: GestureDetector(
              onTap: onAddTapped,
              child: Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.nightfall,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.nightfall.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
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
