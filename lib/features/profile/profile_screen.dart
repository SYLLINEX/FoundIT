import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../main.dart'; // Import to get appThemeNotifier
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';
import '../../models/user_model.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../widgets/found_it_loading_indicator.dart';
import '../../widgets/app_confirmation_dialog.dart';
import 'help_support_screen.dart';
import 'terms_of_service_screen.dart';
import 'about_app_screen.dart';
import 'whats_new_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: FoundItLoadingIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              Map<String, dynamic> data = {};
              if (snapshot.hasData && snapshot.data!.exists) {
                data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              }

              final userModel = UserModel(
                uid: currentUser.uid,
                username:
                    data['username'] ?? currentUser.displayName ?? 'Unknown',
                email: data['email'] ?? currentUser.email ?? '',
                role: data['role'] ?? 'user',
                matricNo: data['matric_no'] ?? '',
                phoneNum: data['phone_num'] ?? '',
                profileImg: data['profile_img'] ?? currentUser.photoURL ?? '',
                createdAt:
                    (data['created_at'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );

              final bottomSpacing = MediaQuery.of(context).padding.bottom + 120;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottomSpacing),
                child: Column(
                  children: [
                    // Custom Top Bar with Avatar
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Dark purple background container
                        Container(
                          margin: const EdgeInsets.only(
                            bottom: 60,
                          ), // Space for the avatar to overlap
                          height: 200,
                          decoration: const BoxDecoration(
                            color: Color(
                              0xFF413F54,
                            ), // Matches the dark appbar color
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 20.0,
                              right: 20.0,
                              top: MediaQuery.of(context).padding.top + 8,
                              bottom: 22,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Profile',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Profile Avatar overlapping the bottom edge
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).scaffoldBackgroundColor, // Match scaffold background to act as border
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 56,
                              backgroundColor: Colors.white,
                              backgroundImage: userModel.profileImg.isNotEmpty
                                  ? NetworkImage(userModel.profileImg)
                                  : null,
                              child: userModel.profileImg.isEmpty
                                  ? const Icon(
                                      PhosphorIconsRegular.user,
                                      size: 50,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // User Info
                    Text(
                      userModel.username.isNotEmpty
                          ? userModel.username
                          : 'Unknown',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userModel.matricNo.isNotEmpty
                          ? userModel.matricNo
                          : 'No ID Available',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Group 1: Edit Profile & Settings
                    _buildMenuCard([
                      _buildMenuItem(
                        context: context,
                        icon: PhosphorIconsFill.userCircle,
                        title: 'Edit Profile',
                        subtitle: 'Change your details',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditProfileScreen(userModel: userModel),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: PhosphorIconsFill.gear,
                        title: 'Settings',
                        subtitle: 'Notifications & Privacy',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: PhosphorIconsFill.chatCircleText,
                        title: 'Messages',
                        subtitle: 'View your conversations',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatListScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: PhosphorIconsFill.bell,
                        title: 'Notifications',
                        subtitle: 'View updates about your reports',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ], context),

                    const SizedBox(height: 16),

                    // Group 1.5: App Preferences & Updates
                    _buildMenuCard([
                      _buildDarkModeItem(context),
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: PhosphorIconsFill.sparkle,
                        title: 'What\'s New',
                        subtitle: 'Latest App Updates',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WhatsNewScreen(),
                            ),
                          );
                        },
                      ),
                    ], context),

                    const SizedBox(height: 16),
                    _buildMenuCard([
                      _buildMenuItem(
                        context: context,
                        icon: PhosphorIconsFill.question,
                        title: 'Help & Support',
                        subtitle: 'FAQ & Contact us',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpSupportScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: PhosphorIconsFill.shieldCheck,
                        title: 'Terms of Service',
                        subtitle: 'Rules & Guidelines',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TermsOfServiceScreen(),
                            ),
                          );
                        },
                      ),
                    ], context),

                    const SizedBox(height: 16),

                    // Group 3: About
                    _buildMenuCard([
                      _buildMenuItem(
                        context: context,
                        icon: PhosphorIconsFill.info,
                        title: 'About FoundIT',
                        subtitle: 'App info & architecture',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AboutAppScreen(),
                            ),
                          );
                        },
                      ),
                    ], context),

                    const SizedBox(height: 32),

                    // Log Out Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ElevatedButton(
                        onPressed: () async {
                          final confirm = await showAppConfirmationDialog<bool>(
                            context: context,
                            title: 'Log Out',
                            message:
                                'Are you sure you want to log out from your account?',
                            confirmText: 'Log Out',
                            confirmColor: Colors.red,
                          );
                          if (confirm != true) return;

                          await AuthService().signOut();
                          if (!context.mounted) return;
                          Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const AuthScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.red.shade900.withOpacity(0.3)
                              : Colors.red.shade50,
                          foregroundColor: isDark
                              ? Colors.red.shade300
                              : Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIconsRegular.signOut, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMenuCard(List<Widget> children, BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurface,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      trailing:
          trailing ??
          Icon(
            PhosphorIconsRegular.caretRight,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
      onTap: onTap,
    );
  }


  Widget _buildDarkModeItem(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                key: ValueKey(isDark),
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
            ),
          ),
          title: Text(
            'Dark Mode',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            'Toggle app theme',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          trailing: Switch(
            value: isDark,
            onChanged: (value) {
              appThemeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          onTap: () {
            appThemeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
          },
        );
      },
    );
  }
}
