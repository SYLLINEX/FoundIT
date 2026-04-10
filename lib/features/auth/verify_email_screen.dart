import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../home/main_wrapper.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../services/auth_service.dart';
import 'auth_screen.dart';
import '../../widgets/found_it_loading_indicator.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../core/utils/app_error_handler.dart';
import '../onboarding/onboarding_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? timer;
  Timer? resendTimer;
  bool isEmailVerified = false;
  bool canResendEmail = false;
  int resendCooldown = 60;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // The user should exist since they just signed up
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // Poll Firebase every 3 seconds to check if they clicked the link
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );

      // Enable the resend button after a short delay (e.g., 60 seconds)
      _startResendCooldown();
    }
  }

  void _startResendCooldown() {
    setState(() {
      canResendEmail = false;
      resendCooldown = 60;
    });

    resendTimer?.cancel();
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (resendCooldown > 0) {
            resendCooldown--;
          } else {
            canResendEmail = true;
            timer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    resendTimer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    try {
      // Calling reload() to refresh user state
      await FirebaseAuth.instance.currentUser?.reload();

      if (!mounted) return;
      setState(() {
        isEmailVerified =
            FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      });

      if (isEmailVerified) {
        timer?.cancel();
        resendTimer?.cancel();

        final isAdmin = await _authService.isAdminUser();
        if (!mounted) return;
        await OnboardingScreen.checkAndRemoveUntil(
          context, 
          isAdmin ? const AdminDashboardScreen() : const MainWrapper()
        );
      }
    } catch (e) {
      // Print the exact error so we can debug why reload is failing if it is
      debugPrint("Error checking email verification: $e");
      
      // Let's ensure the UI updates with the latest known state even if reload() fails
      if (mounted) {
        setState(() {
          isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
        });
        
        if (isEmailVerified) {
          timer?.cancel();
          resendTimer?.cancel();
          
          _authService.isAdminUser().then((isAdmin) {
             if (mounted) {
                OnboardingScreen.checkAndRemoveUntil(
                  context, 
                  isAdmin ? const AdminDashboardScreen() : const MainWrapper()
                );
             }
          });
        }
      }
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      _startResendCooldown();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Check your inbox.'),
          backgroundColor: AppColors.statusFound,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = AppErrorHandler.getMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resending email: $errorMsg')),
      );
    }
  }

  Future<void> _confirmAndLogout() async {
    final confirm = await showAppConfirmationDialog<bool>(
      context: context,
      title: 'Log Out',
      message: 'Are you sure you want to log out? You will need to log in again to verify your email later.',
      confirmText: 'Log Out',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dusk),
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.signOut, color: AppColors.dusk),
            onPressed: _confirmAndLogout,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: checkEmailVerified,
            color: AppColors.deepLavender,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: constraints.maxHeight,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Spacer(),
                Icon(
                  PhosphorIconsLight.envelopeOpen,
                  size: 80,
                  color: AppColors.deepLavender,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Check your Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepLavender,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We have sent a verification link to:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.dusk),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pull down to refresh status if the page doesn\'t automatically update.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dusk,
                  ),
                ),
                const SizedBox(height: 32),
                if (!isEmailVerified) ...[
                  const Center(
                    child: FoundItLoadingIndicator(color: AppColors.deepLavender),
                  ),
                  const SizedBox(height: 24),
                ],
                TextButton(
                  onPressed: canResendEmail ? sendVerificationEmail : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.deepLavender,
                  ),
                  child: Text(
                    canResendEmail 
                        ? 'Resend Verification Link' 
                        : 'Resend Verification Link (${resendCooldown}s)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: canResendEmail
                          ? AppColors.deepLavender
                          : Colors.grey,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      );
      
    }));
    
  }
}
