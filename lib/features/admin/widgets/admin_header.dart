import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';

class AdminHeader extends StatefulWidget {
  final VoidCallback onNotificationTap;

  const AdminHeader({
    super.key,
    required this.onNotificationTap,
  });

  @override
  State<AdminHeader> createState() => _AdminHeaderState();
}

class _AdminHeaderState extends State<AdminHeader> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.nightfall,
            AppColors.nightfall.withOpacity(0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.nightfall.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: currentUser != null
                ? FirebaseFirestore.instance
                      .collection('admins')
                      .doc(currentUser!.uid)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              String adminName = 'Admin';
              String profileImg = '';

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final name = data['name'] ?? data['username'] ?? '';
                if (name.isNotEmpty) {
                  adminName = name.split(' ')[0];
                }
                profileImg = data['profile_img'] ?? '';
              } else if (currentUser != null &&
                  currentUser!.displayName != null) {
                final names = currentUser!.displayName!.split(' ');
                adminName = names.isNotEmpty ? names[0] : 'Admin';
                profileImg = currentUser!.photoURL ?? '';
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $adminName! 👨‍💼',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SRC Management Portal',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.mist,
                      backgroundImage: profileImg.isNotEmpty
                          ? NetworkImage(profileImg)
                          : null,
                      child: profileImg.isEmpty
                          ? const Icon(
                              PhosphorIconsRegular.shieldCheck,
                              color: AppColors.nightfall,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
