import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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
    final cs = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    final onCard = cs.onSurface;
    final subtleColor = cs.onSurfaceVariant;
    final dividerColor = cs.outlineVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Account Section ──────────────────────────────────────────────
          Text(
            'ACCOUNT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onCard.withOpacity(0.45),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            color: cardColor,
            children: [
              ListTile(
                leading: Icon(PhosphorIconsRegular.lockKey, color: onCard),
                title: Text(
                  'Reset Password',
                  style: TextStyle(color: onCard, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Send a password reset link to your email',
                  style: TextStyle(color: subtleColor),
                ),
                trailing: Icon(
                  PhosphorIconsRegular.caretRight,
                  color: onCard.withOpacity(0.3),
                ),
                onTap: () async {
                  final confirmed = await showAppConfirmationDialog<bool>(
                    context: context,
                    title: 'Reset Password?',
                    message: 'Send a reset email to your account address?',
                    confirmText: 'Send',
                    cancelText: 'Cancel',
                  );
                  if (confirmed == true) _resetPassword(context);
                },
              ),
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: dividerColor,
              ),
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.userMinus,
                  color: Colors.red,
                ),
                title: const Text(
                  'Disable / Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Permanently remove your account and data',
                  style: TextStyle(color: Colors.red.withOpacity(0.7)),
                ),
                trailing: const Icon(
                  PhosphorIconsRegular.caretRight,
                  color: Colors.red,
                ),
                onTap: () async {
                  final confirmed = await showAppConfirmationDialog<bool>(
                    context: context,
                    title: 'Delete Account?',
                    message:
                        'Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    confirmColor: Colors.red,
                  );
                  if (confirmed == true) {
                    if (context.mounted) {
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await user.delete();
                          if (context.mounted) {
                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pushReplacementNamed('/auth');
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          final errorMessage = AppErrorHandler.getMessage(e);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to delete account: $errorMessage',
                              ),
                            ),
                          );
                        }
                      }
                    }
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Preferences Section ──────────────────────────────────────────
          Text(
            'PREFERENCES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onCard.withOpacity(0.45),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            color: cardColor,
            children: [
              ListTile(
                leading: Icon(PhosphorIconsRegular.bell, color: onCard),
                title: Text(
                  'Notifications',
                  style: TextStyle(color: onCard, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Stay updated about your reports',
                  style: TextStyle(color: subtleColor),
                ),
                trailing: Switch(
                  value: true,
                  onChanged: (val) {
                    if (!val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Notifications are required to keep you updated about your reports and messages. You cannot disable them.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A rounded card container for settings list tiles.
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color color;

  const _SettingsCard({required this.children, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
