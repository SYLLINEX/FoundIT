import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../home/main_wrapper.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../widgets/found_it_loading_indicator.dart';
import '../../core/theme/app_colors.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Initial Permission Prompt & Warmup for Geolocation
    // We do this here after onboarding so the dashboard doesn't stutter or show skeletons
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );
      }
    } catch (_) {
      // Ignore geography errors here; dashboards will fallback gracefully
    }

    // 2. Resolve Admin Routing
    // Waiting until this screen guarantees Firebase auth is correctly propagated 
    // down the web socket, avoiding false negatives on new accounts.
    final isAdmin = await AuthService().isAdminUser();

    if (!mounted) return;

    if (isAdmin) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AdminDashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.mist,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FoundItLoadingIndicator(size: 60, color: AppColors.deepLavender),
            SizedBox(height: 24),
            Text(
              'Setting things up...',
              style: TextStyle(
                color: AppColors.dusk,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
