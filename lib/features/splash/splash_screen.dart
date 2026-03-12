import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_screen.dart';
import '../home/main_wrapper.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../auth/verify_email_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLoading = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // Step 1: Wait for 2.5 seconds (let GIF animation play)
    // Step 2: Show loading indicator
    // Step 3: Wait another 1.5 seconds, then navigate
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showLoading = true;
        });

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _checkAuthAndNavigate();
          }
        });
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    final user = _authService.currentUser;

    if (user != null) {
      try {
        // This will force check with Firebase servers to see if the user has been deleted or disabled
        await user.reload();
      } catch (e) {
        // If the user was deleted in the backend, sign them out locally
        await _authService.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
        return;
      }

      if (!user.emailVerified) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => VerifyEmailScreen(email: user.email ?? '')),
        );
        return;
      }

      if (!mounted) return;

      bool isAdmin = false;
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          isAdmin = userDoc.data()?['isAdmin'] ?? false;
        }
      } catch (e) {
        // Handle gracefully, default to false
      }

      if (!mounted) return;

      // User is logged in, check if admin
      if (isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainWrapper()),
        );
      }
    } else {
      // User is NOT logged in
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Light icons for the dark splash screen!
        systemNavigationBarIconBrightness: Brightness.light, 
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.deepLavender,
        body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.5 + (value * 0.5), // Scales from 0.5 to 1.0
              child: Opacity(
                opacity: value, // Fades from 0.0 to 1.0
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Option 1: Using the provided icon as per Splash.tsx ---
              // Container(
              //   padding: const EdgeInsets.all(16),
              //   decoration: const BoxDecoration(
              //     color: AppColors.mist,
              //     shape: BoxShape.circle,
              //   ),
              //   child: Icon(
              //     PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
              //     size: 48,
              //     color: AppColors.deepLavender,
              //   ),
              // ),
              
              // --- Option 2: Using your GIF (Uncomment if you want to use the GIF instead of the icon) ---
              Image.asset(
                'assets/images/foundit_animated_logo2.gif', // Make sure to add this path in pubspec.yaml
                width: 400,
                height: 400,
              ),

              const SizedBox(height: 40),

              // Loading Spinner fading in (Windows 10 style)
              AnimatedOpacity(
                opacity: _showLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: const SpinKitWanderingCubes( 
                  color: AppColors.mist,
                  size: 40.0,
                  // lineWidth: 3.0,
                ),
              ),
            ],
          ),
        ),
      ),
      )
  
    );
  }
}


