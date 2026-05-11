import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_verifications_tab.dart';
import 'tabs/admin_map_tab.dart';
import 'tabs/admin_analytics_tab.dart';
import 'tabs/admin_profile_tab.dart';
import 'widgets/admin_bottom_nav_bar.dart';
import '../../widgets/feature_tour/feature_tour_controller.dart';
import '../../widgets/feature_tour/feature_tour_step.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final GlobalKey _dashboardTabKey = GlobalKey(debugLabel: 'admin_tour_dashboard');
  final GlobalKey _verificationsTabKey = GlobalKey(debugLabel: 'admin_tour_verifications');
  final GlobalKey _mapTabKey = GlobalKey(debugLabel: 'admin_tour_map');
  final GlobalKey _analyticsTabKey = GlobalKey(debugLabel: 'admin_tour_analytics');
  final GlobalKey _profileTabKey = GlobalKey(debugLabel: 'admin_tour_profile');

  late FeatureTourController _tourController;

  final List<Widget> _tabs = const [
    AdminDashboardTab(),
    AdminVerificationsTab(),
    AdminMapTab(),
    AdminAnalyticsTab(),
    AdminProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _tourController = FeatureTourController(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartTour();
    });
  }

  Future<void> _maybeStartTour() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenAdminFeatureTour') ?? false;
    if (hasSeen || !mounted) return;

    _tourController.start(
      _buildTourSteps(),
      onCompleted: () async {
        final p = await SharedPreferences.getInstance();
        await p.setBool('hasSeenAdminFeatureTour', true);
      },
    );
  }

  List<FeatureTourStep> _buildTourSteps() => [
    FeatureTourStep(
      targetKey: _dashboardTabKey,
      title: 'Admin Dashboard',
      description: 'Get an overview of recent reports, active claims, and overall platform health.',
      tooltipPosition: TooltipPosition.above,
    ),
    FeatureTourStep(
      targetKey: _verificationsTabKey,
      title: 'Verifications',
      description: 'Review pending claim disputes and verify user identities to keep the community safe.',
      tooltipPosition: TooltipPosition.above,
    ),
    FeatureTourStep(
      targetKey: _mapTabKey,
      title: 'Global Map',
      description: 'Monitor item reports geographically to identify hotspots across the campus.',
      tooltipPosition: TooltipPosition.above,
    ),
    FeatureTourStep(
      targetKey: _analyticsTabKey,
      title: 'Analytics',
      description: 'Dive deep into usage metrics, resolution rates, and platform trends.',
      tooltipPosition: TooltipPosition.above,
    ),
    FeatureTourStep(
      targetKey: _profileTabKey,
      title: 'Admin Settings',
      description: 'Manage your admin profile, configure notifications, and check the latest app updates.',
      tooltipPosition: TooltipPosition.above,
    ),
  ];

  @override
  void dispose() {
    _tourController.dispose();
    super.dispose();
  }

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
            dashboardTabKey: _dashboardTabKey,
            verificationsTabKey: _verificationsTabKey,
            mapTabKey: _mapTabKey,
            analyticsTabKey: _analyticsTabKey,
            profileTabKey: _profileTabKey,
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
