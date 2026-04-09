import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../core/utils/app_error_handler.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _resetPassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password reset email sent to ${user.email}'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errorMessage = AppErrorHandler.getMessage(e);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No email associated with this account or user not logged in.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.lockKey),
            title: const Text('Reset Password'),
            subtitle: const Text('Send a password reset link to your email'),
            trailing: const Icon(PhosphorIconsRegular.caretRight),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () async {
              final confirmed = await showAppConfirmationDialog<bool>(
                context: context,
                title: 'Reset Password?',
                message: 'Send a reset email to your account address?',
                confirmText: 'Send',
                cancelText: 'Cancel',
              );

              if (confirmed == true) {
                _resetPassword(context);
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Preferences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.bell),
            title: const Text('Notifications'),
            trailing: Switch(
              value: true,
              onChanged: (val) {
                // TODO: Handle notification preferences
              },
            ),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}
