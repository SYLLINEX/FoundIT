import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../notifications/notifications_screen.dart';
import '../../chat/chat_list_screen.dart';
import '../../../services/notification_service.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  final NotificationService _notificationService = NotificationService();
  final ValueNotifier<bool> _isSearchExpanded = ValueNotifier<bool>(false);
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeTextAnimation;
  late Animation<double> _fadeIconAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeTextAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeIn)),
    );
    _fadeIconAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isSearchExpanded.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: topPadding + 64,
        padding: EdgeInsets.only(top: topPadding, left: 24, right: 16),
        decoration: BoxDecoration(
          color: AppColors.nightfall, // Dark theme map to user mockup
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Profile Avatar replacing hamburger
            FadeTransition(
              opacity: _fadeIconAnimation,
              child: StreamBuilder<DocumentSnapshot>(
                stream: currentUser != null
                    ? FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots()
                    : null,
                builder: (context, snapshot) {
                  String profileImg = '';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    profileImg = (snapshot.data!.data() as Map<String, dynamic>)['profile_img'] as String? ?? '';
                  } else if (currentUser?.photoURL != null) {
                    profileImg = currentUser!.photoURL!;
                  }

                  return CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                    child: profileImg.isEmpty ? const Icon(PhosphorIconsRegular.user, color: Colors.white, size: 24) : null,
                  );
                },
              ),
            ),
            
            const SizedBox(width: 14),

            // Middle: Title Column mapped to mockup constraints
            Expanded(
              child: FadeTransition(
                opacity: _fadeTextAnimation,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: currentUser != null
                      ? FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots()
                      : null,
                  builder: (context, snapshot) {
                    String firstName = 'User';
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final username = data['username'] as String? ?? '';
                      if (username.isNotEmpty) {
                        firstName = username.split(' ')[0];
                      }
                    } else if (currentUser != null && currentUser!.displayName != null) {
                      final names = currentUser!.displayName!.split(' ');
                      firstName = names.isNotEmpty ? names[0] : 'User';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Hi, $firstName! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Looking for something?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            
            // Right: Search Icon replacing plus, expanding into field gracefully
            FadeTransition(
              opacity: _fadeIconAnimation,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isSearchExpanded,
                builder: (context, isExpanded, child) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isExpanded ? 200 : 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isExpanded ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      border: isExpanded ? Border.all(color: Colors.transparent) : null,
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _isSearchExpanded.value = !isExpanded;
                            if (isExpanded) {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            }
                          },
                          child: Container(
                            height: 44,
                            width: 44,
                            color: Colors.transparent,
                            child: Icon(
                              isExpanded ? PhosphorIconsRegular.x : PhosphorIconsLight.magnifyingGlass,
                              color: isExpanded ? AppColors.nightfall : Colors.white70,
                              size: 24,
                            ),
                          ),
                        ),
                        Expanded(
                          child: isExpanded
                              ? ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _searchController,
                                  builder: (context, textValue, child) {
                                    return TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      style: const TextStyle(color: AppColors.nightfall, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Search FoundIT...',
                                        hintStyle: const TextStyle(color: Colors.black38),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                                        suffixIcon: textValue.text.isNotEmpty
                                            ? GestureDetector(
                                                onTap: () => _searchController.clear(),
                                                child: const Icon(PhosphorIconsRegular.x, color: Colors.grey, size: 16),
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 4),

            // MoreVert (Triple Dot) -> Notifications/Messages matching the mockup menu entry logic
            FadeTransition(
              opacity: _fadeIconAnimation,
              child: StreamBuilder<QuerySnapshot>(
                stream: currentUser != null 
                    ? FirebaseFirestore.instance.collection('chat_rooms').where('participants', arrayContains: currentUser!.uid).snapshots()
                    : null,
                builder: (context, chatSnap) {
                  int unreadChats = 0;
                  if (chatSnap.hasData) {
                     for (var doc in chatSnap.data!.docs) {
                         final data = doc.data() as Map<String, dynamic>;
                         final countData = data['unread_counts'] as Map<String, dynamic>?;
                         if (countData != null) {
                             unreadChats += (countData[currentUser!.uid] as num?)?.toInt() ?? 0;
                         }
                     }
                  }
                  return StreamBuilder<int>(
                    stream: currentUser != null ? _notificationService.getUnreadCountStream(currentUser!.uid) : null,
                    builder: (context, unreadSnapshot) {
                      final unreadNotifications = unreadSnapshot.data ?? 0;
                      final totalUnread = unreadChats + unreadNotifications;
                      
                      return PopupMenuButton<String>(
                        offset: const Offset(0, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: Colors.white,
                        elevation: 4,
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(PhosphorIconsLight.dotsThreeVertical, color: Colors.white70, size: 28),
                            if (totalUnread > 0)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.nightfall, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onSelected: (value) {
                          if (value == 'messages') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
                          } else if (value == 'notifications') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'messages',
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Messages', style: TextStyle(color: Colors.grey.shade800, fontSize: 16)),
                                if (unreadChats > 0)
                                  CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Text('$unreadChats', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          PopupMenuItem(
                            value: 'notifications',
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Notifications', style: TextStyle(color: Colors.grey.shade800, fontSize: 16)),
                                if (unreadNotifications > 0)
                                  CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Text('$unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}
