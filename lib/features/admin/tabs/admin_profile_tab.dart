import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../services/auth_service.dart';
import '../../auth/auth_screen.dart';
import '../../notifications/notifications_screen.dart';
import '../../../widgets/found_it_loading_indicator.dart';
import '../../../models/user_model.dart';
import '../../profile/edit_profile_screen.dart';
import '../../profile/settings_screen.dart';
import '../../chat/chat_list_screen.dart';

class AdminProfileTab extends StatelessWidget {
  const AdminProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admins')
            .doc(currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: FoundItLoadingIndicator());
          }

          Map<String, dynamic> data = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          }

          final adminName = data['username'] ?? data['name'] ?? 'Admin';
          final adminEmail = data['email'] ?? currentUser.email ?? '';
          final profileImg = data['profile_img'] ?? currentUser.photoURL ?? '';

          final userModel = UserModel(
            uid: currentUser.uid,
            username: adminName,
            email: adminEmail,
            role: 'admin',
            matricNo: data['matric_no'] ?? '',
            phoneNum: data['phone_num'] ?? '',
            profileImg: profileImg,
            createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
                        margin: const EdgeInsets.only(bottom: 60),
                        height: 160,
                        decoration: const BoxDecoration(
                          color: Color(0xFF413F54),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 20.0,
                            right: 20.0,
                            top: MediaQuery.of(context).padding.top + 10,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Admin Profile',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
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
                        bottom: -10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F2F6),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                            child: profileImg.isEmpty
                                ? const Icon(
                                    PhosphorIconsRegular.user,
                                    size: 40,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),

                  // Admin Info
                  Text(
                    adminName.isNotEmpty ? adminName : 'Admin',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF262532),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminEmail,
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
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFEEEDF2),
                    ),
                    _buildMenuItem(
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
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFEEEDF2),
                    ),
                    _buildMenuItem(
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
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFEEEDF2),
                    ),
                    _buildMenuItem(
                      icon: PhosphorIconsFill.bell,
                      title: 'Notifications',
                      subtitle: 'View system updates',
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
                      icon: PhosphorIconsFill.question,
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
                      icon: PhosphorIconsFill.shieldCheck,
                      title: 'Terms of Service',
                      subtitle: 'Rules & Guidelines',
                      onTap: () {
                        // Placeholder
                      },
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // Log Out Button
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
        PhosphorIconsRegular.caretRight,
        size: 16,
        color: Color(0xFFD1D1D6),
      ),
      onTap: onTap,
    );
  }
}
