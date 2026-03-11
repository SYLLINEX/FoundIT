import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to AuthScreen/Login after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    });
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.mist,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
                  size: 48,
                  color: AppColors.deepLavender,
                ),
              ),
              
              // --- Option 2: Using your GIF (Uncomment if you want to use the GIF instead of the icon) ---
              // Image.asset(
              //   'assets/images/loading.gif', // Make sure to add this path in pubspec.yaml
              //   width: 80,
              //   height: 80,
              // ),

              const SizedBox(height: 16),
              const Text(
                'FoundIT',
                style: TextStyle(
                  fontSize: 36, // ~4xl
                  fontWeight: FontWeight.bold,
                  color: AppColors.mist,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'LOST & FOUND SYSTEM',
                style: TextStyle(
                  fontSize: 14, // text-sm
                  letterSpacing: 2.0, // tracking-widest
                  color: AppColors.silverShadow,
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

