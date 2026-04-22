import 'package:flutter/material.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_verifications_tab.dart';
import 'tabs/admin_map_tab.dart';
import 'tabs/admin_analytics_tab.dart';
import 'tabs/admin_profile_tab.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
        body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
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
