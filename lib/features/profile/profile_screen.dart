import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../widgets/found_it_loading_indicator.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: const Color(
        0xFFF2F2F6,
      ), // Light grayish background matching the screenshot
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
            username: data['username'] ?? currentUser.displayName ?? 'Unknown',
            email: data['email'] ?? currentUser.email ?? '',
            role: data['role'] ?? 'user',
            matricNo: data['matric_no'] ?? '',
            phoneNum: data['phone_num'] ?? '',
            profileImg: data['profile_img'] ?? currentUser.photoURL ?? '',
            createdAt:
                (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
                          padding: const EdgeInsets.all(
                            6,
                          ), // White border effect
                          decoration: const BoxDecoration(
                            color: Color(
                              0xFFF2F2F6,
                            ), // Match scaffold background to act as border
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
                                    Icons.person,
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
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF262532),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userModel.matricNo.isNotEmpty
                        ? userModel.matricNo
                        : 'No ID Available',
                    style: const TextStyle(
                      color: Color(0xFF6B6A7C),
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Group 1: Edit Profile & Settings
                  _buildMenuCard([
                    _buildMenuItem(
                      icon: PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
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
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFEEEDF2),
                    ),
                    _buildMenuItem(
                      icon: PhosphorIcons.gear(PhosphorIconsStyle.fill),
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
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFEEEDF2),
                    ),
                    _buildMenuItem(
                      icon: PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill),
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
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFEEEDF2),
                    ),
                    _buildMenuItem(
                      icon: PhosphorIcons.bell(PhosphorIconsStyle.fill),
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
                  ]),

                  const SizedBox(height: 16),

                  // Group 2: Help & Support & Terms of Service
                  _buildMenuCard([
                    _buildMenuItem(
                      icon: PhosphorIcons.question(PhosphorIconsStyle.fill),
                      title: 'Help & Support',
                      subtitle: 'FAQ & Contact us',
                      onTap: () {
                        // Placeholder
                      },
                    ),
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFEEEDF2),
                    ),
                    _buildMenuItem(
                      icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                      title: 'Terms of Service',
                      subtitle: 'Rules & Guidelines',
                      onTap: () {
                        // Placeholder
                      },
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // Log Out Button matching screenshot
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ElevatedButton(
                      onPressed: () async {
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
                        backgroundColor: const Color(0xFFFBE8EA),
                        foregroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 20),
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
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F2F6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF413F54), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF262532),
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF6B6A7C), fontSize: 13),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Color(0xFFD1D1D6),
      ),
      onTap: onTap,
    );
  }
}
