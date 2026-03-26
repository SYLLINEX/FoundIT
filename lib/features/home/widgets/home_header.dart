import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../notifications/notifications_screen.dart';
import '../../chat/chat_list_screen.dart';
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
      padding: const EdgeInsets.only(top: 50, left: 18, right: 18, bottom: 20),
      decoration: const BoxDecoration(
        color: AppColors.nightfall,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
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
                  Expanded(
                    child: Text(
                      'Hi, $firstName! 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      if (currentUser != null)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('chat_rooms').where('participants', arrayContains: currentUser!.uid).snapshots(),
                          builder: (context, chatSnap) {
                            int unreadChats = 0;
                            if (chatSnap.hasData) {
                               for (var doc in chatSnap.data!.docs) {
                                   final data = doc.data() as Map<String, dynamic>;
                                   final countData = data['unread_counts'] as Map<String, dynamic>?;
                                   if (countData != null) {
                                       int myCount = countData[currentUser!.uid] ?? 0;
                                       unreadChats += myCount;
                                   }
                               }
                            }
                            return StreamBuilder<int>(
                              stream: _notificationService.getUnreadCountStream(currentUser!.uid),
                              builder: (context, unreadSnapshot) {
                                final unreadNotifications = unreadSnapshot.data ?? 0;
                                final totalUnread = unreadChats + unreadNotifications;
                                
                                return PopupMenuButton<String>(
                                  offset: const Offset(0, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  color: Colors.white,
                                  onSelected: (value) {
                                    if (value == 'messages') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const ChatListScreen()),
                                      );
                                    } else if (value == 'notifications') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                      );
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'messages',
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.chat_bubble_outline, color: AppColors.nightfall, size: 20),
                                              SizedBox(width: 12),
                                              Text('Messages', style: TextStyle(color: AppColors.nightfall, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                          if (unreadChats > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                              child: Text(
                                                unreadChats > 99 ? '99+' : unreadChats.toString(),
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem<String>(
                                      value: 'notifications',
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.notifications_none, color: AppColors.nightfall, size: 20),
                                              SizedBox(width: 12),
                                              Text('Notifications', style: TextStyle(color: AppColors.nightfall, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                          if (unreadNotifications > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                              child: Text(
                                                unreadNotifications > 99 ? '99+' : unreadNotifications.toString(),
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
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
                                      if (totalUnread > 0)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppColors.nightfall, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                        )
                      else
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
