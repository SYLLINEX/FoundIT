import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../notifications/notifications_screen.dart';
import '../../auth/auth_screen.dart';
import '../../../widgets/app_confirmation_dialog.dart';

class AdminProfileMenu extends StatefulWidget {
  final int unreadNotifications;

  const AdminProfileMenu({
    super.key,
    required this.unreadNotifications,
  });

  @override
  State<AdminProfileMenu> createState() => _AdminProfileMenuState();
}

class _AdminProfileMenuState extends State<AdminProfileMenu> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
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
          adminName = data['username'] ?? data['name'] ?? 'Admin';
          profileImg = data['profile_img'] ?? '';
        }

        return PopupMenuButton<String>(
          constraints: const BoxConstraints(
            minWidth: 250,
            maxWidth: 300,
          ),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (BuildContext context) {
            return <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.mist,
                          backgroundImage: profileImg.isNotEmpty
                              ? NetworkImage(profileImg)
                              : null,
                          child: profileImg.isEmpty
                              ? const Icon(
                                  PhosphorIconsRegular.shieldCheck,
                                  color: AppColors.nightfall,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adminName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                currentUser?.email ?? 'admin-user',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                  ],
                ),
              ),
              if (currentUser != null)
                PopupMenuItem<String>(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.bell,
                          color: Colors.red,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'You have ${widget.unreadNotifications} unread',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.unreadNotifications > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.unreadNotifications > 99
                                ? '99+'
                                : widget.unreadNotifications.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.signOut,
                        color: Colors.red.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                onTap: () async {
                  Navigator.of(context).pop();

                  final confirm = await showAppConfirmationDialog<bool>(
                    context: context,
                    title: 'Log Out',
                    message: 'Are you sure you want to log out of the admin panel?',
                    confirmText: 'Log Out',
                    confirmColor: Colors.red,
                  );
                  if (confirm != true) return;

                  await AuthService().signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ];
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.mist,
                backgroundImage: profileImg.isNotEmpty
                    ? NetworkImage(profileImg)
                    : null,
                child: profileImg.isEmpty
                    ? const Icon(
                        PhosphorIconsRegular.shieldCheck,
                        color: AppColors.nightfall,
                        size: 18,
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
