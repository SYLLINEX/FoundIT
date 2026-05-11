import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../models/chat_room_model.dart';
import '../../services/encryption_service.dart';
import '../../widgets/empty_state_view.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  /// Deletes expired chat rooms from Firestore (fire-and-forget)
  void _pruneExpiredChats(List<ChatRoomModel> expired) {
    if (expired.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final chat in expired) {
      batch.delete(
        FirebaseFirestore.instance.collection('chat_rooms').doc(chat.id),
      );
    }
    batch.commit().catchError((_) {}); // silent — best effort
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading messages: ${snapshot.error}'));
          }

          final now = DateTime.now();
          final allChats = (snapshot.data?.docs ?? [])
              .map((doc) => ChatRoomModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          // Split into expired vs active
          final expired = allChats
              .where((c) => c.expiresAt != null && c.expiresAt!.isBefore(now))
              .toList();
          final activeChats = allChats
              .where((c) => c.expiresAt == null || c.expiresAt!.isAfter(now))
              .toList();

          // Delete expired chats from Firestore (fire-and-forget)
          if (expired.isNotEmpty) _pruneExpiredChats(expired);

          // Sort by most recent
          activeChats.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

          if (activeChats.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: activeChats.length,
            itemBuilder: (context, index) =>
                ChatListRoomTile(room: activeChats[index], currentUserId: currentUser.uid),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateView(
      icon: PhosphorIconsRegular.chatCircle,
      title: 'No active messages',
      message: 'When a claim is approved, your secure\nprivate chat will appear here.',
    );
  }
}


class ChatListRoomTile extends StatelessWidget {
  final ChatRoomModel room;
  final String currentUserId;

  const ChatListRoomTile({super.key, required this.room, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final otherUserId = room.participants.firstWhere((id) => id != currentUserId, orElse: () => '');

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('items').doc(room.itemId).get(),
      builder: (context, itemSnap) {
        String itemTitle = 'Loading item...';
        String imageUrl = '';
        if (itemSnap.hasData && itemSnap.data!.exists) {
          final itemData = itemSnap.data!.data() as Map<String, dynamic>?;
          if (itemData != null) {
            itemTitle = itemData['title'] ?? 'Unknown Item';
            imageUrl = itemData['image_url'] ?? '';
          }
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
          builder: (context, userSnap) {
            String otherName = 'Loading user...';
            String otherProfilePic = '';
            if (userSnap.hasData && userSnap.data!.exists) {
              final userData = userSnap.data!.data() as Map<String, dynamic>?;
              if (userData != null) {
                otherName = userData['username'] ?? 'User';
                otherProfilePic = userData['profile_img'] ?? '';
              }
            }

            final decryptedLastMessage = EncryptionService.decryptMessage(room.lastMessage, room.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.mist,
                  backgroundImage: otherProfilePic.isNotEmpty ? NetworkImage(otherProfilePic) : null,
                  child: otherProfilePic.isEmpty ? const Icon(PhosphorIconsRegular.user, color: Colors.grey, size: 28) : null,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        itemTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          timeago.format(room.lastUpdated, locale: 'en_short'),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        if ((room.unreadCounts[currentUserId] ?? 0) > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            child: Text(
                              room.unreadCounts[currentUserId].toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'With $otherName',
                      style: TextStyle(color: Colors.indigo.shade400, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      decryptedLastMessage.isEmpty ? 'Tap to start chatting' : decryptedLastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(room: room, itemTitle: itemTitle, itemImageUrl: imageUrl, otherProfilePicUrl: otherProfilePic, otherUserName: otherName, otherUserId: otherUserId),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
