import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_screen.dart';
import '../home/main_wrapper.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../auth/verify_email_screen.dart';

import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLoading = false;
  final AuthService _authService = AuthService();

  final List<String> _loadingMessages = [
    "Waking up the search dogs...",
    "Looking under the couch cushions...",
    "Checking the lost and found box...",
    "Applying magic tracking dust...",
    "Almost ready to find it...",
  ];
  int _currentMessageIndex = 0;
  bool _timerActive = true;

  @override
  void initState() {
    super.initState();
    _startMessageCycle();

    // Step 1: Wait for 1.5 seconds (let GIF animation loop)
    // Step 2: Show loading indicator
    // Step 3: Wait another 2.5 seconds, then navigate
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showLoading = true;
        });

        Future.delayed(const Duration(milliseconds: 3000), () {
          if (mounted) {
            _checkAuthAndNavigate();
          }
        });
      }
    });
  }

  void _startMessageCycle() async {
    // Wait a bit before showing the first message switch
    await Future.delayed(const Duration(milliseconds: 1500));
    while (_timerActive && mounted) {
      await Future.delayed(const Duration(milliseconds: 2000));
      if (_timerActive && mounted) {
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _loadingMessages.length;
        });
      }
    }
  }

  @override
  void dispose() {
    _timerActive = false;
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    final user = _authService.currentUser;
    Widget nextScreen;

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
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(email: user.email ?? ''),
          ),
        );
        return;
      }

      if (!mounted) return;

      final isAdmin = await _authService.isAdminUser(user.uid);

      if (!mounted) return;

      // User is logged in, check if admin
      if (isAdmin) {
        nextScreen = const AdminDashboardScreen();
      } else {
        nextScreen = const MainWrapper();
      }
    } else {
      // User is NOT logged in
      nextScreen = const AuthScreen();
    }

    if (mounted) {
      if (user != null && nextScreen is! AuthScreen) {
        // If they are logged in and skipping auth screen, verify onboarding
        await OnboardingScreen.checkAndNavigate(context, nextScreen);
      } else {
        // If they need to login/signup, don't show onboarding yet
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.deepLavender,
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2), // Pop-in effect
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0), // Clamp to prevent out-of-bounds from elastic out
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The new GIF
                Image.asset(
                  'assets/images/foundit_animated_logo.gif',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 40),

                // Loading Spinner + Messages fading in
                AnimatedOpacity(
                  opacity: _showLoading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    children: [
                      const SpinKitFadingCube(
                        color: AppColors.mist,
                        size: 35.0,
                      ),
                      const SizedBox(height: 30),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _loadingMessages[_currentMessageIndex],
                          key: ValueKey<int>(_currentMessageIndex),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
