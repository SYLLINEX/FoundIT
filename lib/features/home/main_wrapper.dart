import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/feature_tour/feature_tour_controller.dart';
import '../../widgets/feature_tour/feature_tour_step.dart';
import '../map/map_dashboard_screen.dart';
import '../report_item/report_item_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/my_reports_screen.dart';
import 'home_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  // ── GlobalKeys for feature tour spotlight targets ─────────────────────────
  final GlobalKey _homeTabKey    = GlobalKey(debugLabel: 'tour_home');
  final GlobalKey _mapTabKey     = GlobalKey(debugLabel: 'tour_map');
  final GlobalKey _fabKey        = GlobalKey(debugLabel: 'tour_fab');
  final GlobalKey _reportsTabKey = GlobalKey(debugLabel: 'tour_reports');
  final GlobalKey _profileTabKey = GlobalKey(debugLabel: 'tour_profile');

  late FeatureTourController _tourController;

  final List<Widget> _screens = const [
    HomeScreen(),
    MapDashboardScreen(),
    MyReportsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tourController = FeatureTourController(context);

    // Wait for the first frame so all GlobalKeys are resolved, then check tour
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartTour();
    });
  }

  Future<void> _maybeStartTour() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenFeatureTour') ?? false;
    if (hasSeen || !mounted) return;

    _tourController.start(
      _buildTourSteps(),
      onCompleted: () async {
        final p = await SharedPreferences.getInstance();
        await p.setBool('hasSeenFeatureTour', true);
      },
    );
  }

  List<FeatureTourStep> _buildTourSteps() => [
    FeatureTourStep(
      targetKey: _homeTabKey,
      title: 'Home Feed',
      description:
          'Browse lost & found items reported near your location in real time.',
      tooltipPosition: TooltipPosition.above,
    ),
    FeatureTourStep(
      targetKey: _mapTabKey,
      title: 'Map View',
      description:
          'See all nearby reports pinned on a live map — great for spotting patterns.',
      tooltipPosition: TooltipPosition.above,
    ),
    FeatureTourStep(
      targetKey: _fabKey,
      title: 'Report an Item',
      description:
          'Tap the + button to report something you lost or found. Add photos and let AI do the matching!',
      tooltipPosition: TooltipPosition.above,
    ),
    FeatureTourStep(
      targetKey: _reportsTabKey,
      title: 'My Reports',
      description:
          'Track the status of all your active reports and check for incoming claims.',
      tooltipPosition: TooltipPosition.above,
    ),
    FeatureTourStep(
      targetKey: _profileTabKey,
      title: 'Your Profile',
      description:
          'Manage your account, toggle dark mode, and view your activity history.',
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
            children: _screens,
          ),
          CustomBottomNavBar(
            selectedIndex: _currentIndex,
            homeTabKey: _homeTabKey,
            mapTabKey: _mapTabKey,
            fabKey: _fabKey,
            reportsTabKey: _reportsTabKey,
            profileTabKey: _profileTabKey,
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
