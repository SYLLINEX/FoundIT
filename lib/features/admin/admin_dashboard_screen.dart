import 'package:flutter/material.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_verifications_tab.dart';
import 'tabs/admin_map_tab.dart';
import 'tabs/admin_analytics_tab.dart';
import 'tabs/admin_profile_tab.dart';
import 'widgets/admin_minimal_header.dart';
import 'widgets/admin_bottom_nav_bar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  final List<Widget> _tabs = const [
    AdminDashboardTab(),
    AdminVerificationsTab(),
    AdminMapTab(),
    AdminAnalyticsTab(),
    AdminProfileTab(),
  ];

  final List<String> _pageTitles = [
    'Dashboard',
    'Verifications',
    'Map',
    'Analytics',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          // Map (2) and Profile (4) tabs - full screen without header
          (_currentIndex == 2 || _currentIndex == 4)
              ? _tabs[_currentIndex]
              : // Other tabs - with dynamic header
              Column(
                  children: [
                    AdminMinimalHeader(title: _pageTitles[_currentIndex]),
                    Expanded(child: _tabs[_currentIndex]),
                  ],
                ),
          AdminBottomNavBar(
            selectedIndex: _currentIndex,
            onItemTapped: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ],
      ),
    );
  }
}
