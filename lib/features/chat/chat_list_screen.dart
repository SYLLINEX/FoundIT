import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../models/chat_room_model.dart';
import '../../services/encryption_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: AppColors.obsidian, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.obsidian),
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

          final docs = snapshot.data?.docs ?? [];
          final activeChats = docs.map((doc) => ChatRoomModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
          
          // Sort locally to bypass Firebase Composite Index missing error
          activeChats.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

          if (activeChats.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: activeChats.length,
            itemBuilder: (context, index) {
              return ChatListRoomTile(room: activeChats[index], currentUserId: currentUser.uid);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No active messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.obsidian)),
          const SizedBox(height: 8),
          const Text('When a claim is approved, your secure\nprivate chat will appear here.', 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.grey, height: 1.4)
          ),
        ],
      ),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.mist,
                  backgroundImage: otherProfilePic.isNotEmpty ? NetworkImage(otherProfilePic) : null,
                  child: otherProfilePic.isEmpty ? const Icon(Icons.person, color: Colors.grey, size: 28) : null,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        itemTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.obsidian),
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
