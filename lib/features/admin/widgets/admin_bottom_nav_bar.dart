import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AdminBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AdminBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<AdminBottomNavBar> createState() => _AdminBottomNavBarState();
}

class _AdminBottomNavBarState extends State<AdminBottomNavBar> {
  // Maintained your original labels
  final List<String> _labels = [
    'Dashboard',
    'Verifications',
    'Map',
    'Analytics',
    'Profile',
  ];

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
        // spaceEvenly perfectly distributes the changing widths during animation
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
    bool isSelected = widget.selectedIndex == index;

    return GestureDetector(
      onTap: () => widget.onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          // Soft slate-blue color pulled from your screenshot reference
          color: isSelected ? const Color(0xFF385374) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white60,
              size: 26,
            ),
            // AnimatedSize handles the smooth expanding/collapsing of the label
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        _labels[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  // Maintaining the height of the icon (26) prevents vertical jumping
                  : const SizedBox(width: 0, height: 26), 
            ),
          ],
        ),
      ),
    );
  }
}