import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../map/map_dashboard_screen.dart';
import '../report_item/report_item_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MapDashboardScreen(),
    const Scaffold(body: Center(child: Text('My Items / Feed'))), // Placeholder for list view
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _screens[_currentIndex],
          CustomBottomNavBar(
            selectedIndex: _currentIndex,
            onItemTapped: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            onAddTapped: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportItemScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
