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

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? timer;
  bool isEmailVerified = false;
  bool canResendEmail = false;
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
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    // Calling reload() to refresh user state
    await FirebaseAuth.instance.currentUser?.reload();

    setState(() {
      isEmailVerified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      timer?.cancel();

      if (mounted) {
        final isAdmin = await _authService.isAdminUser();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                isAdmin ? const AdminDashboardScreen() : const MainWrapper(),
          ),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 15));
      setState(() => canResendEmail = true);
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 8),
              const Text(
                'Click the link to verify your account. This page will automatically update once verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.dusk,
                ),
              ),
              const SizedBox(height: 48),
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
                  'Resend Verification Link',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: canResendEmail
                        ? AppColors.deepLavender
                        : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _confirmAndLogout,
                icon: Icon(PhosphorIconsRegular.signOut, color: AppColors.error),
                label: const Text(
                  'Back to Login / Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
