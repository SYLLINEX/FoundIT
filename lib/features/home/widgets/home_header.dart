import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../notifications/notifications_screen.dart';
import '../../../services/notification_service.dart';
import 'category_tabs.dart';

class HomeHeader extends StatefulWidget {
  final List<String> categories;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;

  const HomeHeader({
    super.key,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: AppColors.nightfall,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: currentUser != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              String firstName = 'User';
              String profileImg = '';

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final username = data['username'] as String? ?? '';
                if (username.isNotEmpty) {
                  firstName = username.split(' ')[0];
                }
                profileImg = data['profile_img'] as String? ?? '';
              } else if (currentUser != null &&
                  currentUser!.displayName != null) {
                final names = currentUser!.displayName!.split(' ');
                firstName = names.isNotEmpty ? names[0] : 'User';
                profileImg = currentUser!.photoURL ?? '';
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hi, $firstName! 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (currentUser != null)
                        StreamBuilder<int>(
                          stream: _notificationService.getUnreadCountStream(
                            currentUser!.uid,
                          ),
                          builder: (context, unreadSnapshot) {
                            final unread = unreadSnapshot.data ?? 0;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.notifications_none,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        unread > 99 ? '99+' : unread.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.mist,
                        backgroundImage: profileImg.isNotEmpty
                            ? NetworkImage(profileImg)
                            : null,
                        child: profileImg.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: AppColors.nightfall,
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Lost something today?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      hintStyle: TextStyle(color: Colors.black38),
                      prefixIcon: Icon(Icons.search, color: Colors.black38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CategoryTabs(
                categories: widget.categories,
                selectedIndex: widget.selectedCategoryIndex,
                onTabSelected: widget.onCategorySelected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
