import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:async';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/chat_room_model.dart';
import '../../models/message_model.dart';
import '../../services/encryption_service.dart';
import '../../widgets/found_it_loading_indicator.dart';
import '../../widgets/app_confirmation_dialog.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class ChatScreen extends StatefulWidget {
  final ChatRoomModel room;
  final String itemTitle;
  final String itemImageUrl;
  final String otherProfilePicUrl;
  final String otherUserName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.room,
    required this.itemTitle,
    required this.itemImageUrl,
    required this.otherProfilePicUrl,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AuthService _authService = AuthService();
  Timer? _typingTimer;
  
  late StreamSubscription _roomSub;
  late Stream<QuerySnapshot> _messagesStream;

  // Tracks the full resolved_by map from Firestore (userId -> true/false)
  final ValueNotifier<Map<String, dynamic>> _resolvedBy = ValueNotifier({});
  final ValueNotifier<bool> _isClosed = ValueNotifier(false);
  final ValueNotifier<bool> _isOtherTyping = ValueNotifier(false);
  
  bool _showEmojiKeyboard = false;
  MessageModel? _replyingToMessage;
  String _replyingToDecryptedText = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _msgController.addListener(_onTextChanged);

    _messagesStream = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.room.id)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
    
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id).update({
        'unread_counts.$uid': 0,
        'active_users.$uid': true,
      });
    }

    _roomSub = FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id).snapshots().listen((snap) {
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        _isClosed.value = data['status'] == 'closed';
        final typingMap = data['typing_status'] as Map<String, dynamic>? ?? {};
        _isOtherTyping.value = typingMap[widget.otherUserId] == true;
        _resolvedBy.value = Map<String, dynamic>.from(data['resolved_by'] ?? {});
      }
    });
  }

  @override
  void dispose() {
    _roomSub.cancel();
    _typingTimer?.cancel();
    _msgController.dispose();
    _focusNode.dispose();
    
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id).update({
        'typing_status.$uid': false,
        'active_users.$uid': false,
      });
    }
    super.dispose();
  }

  void _onTextChanged() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    
    FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id).update({
      'typing_status.$uid': true,
    });
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id).update({
        'typing_status.$uid': false,
      });
    });
  }

  void _onEmojiButtonPressed() {
    setState(() {
      _showEmojiKeyboard = !_showEmojiKeyboard;
      if (_showEmojiKeyboard) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;

    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSending = true);

    try {
      _msgController.clear();
      _typingTimer?.cancel();
      
      final replyEncrypted = _replyingToMessage != null ? _replyingToMessage!.text : '';
      setState(() {
        _replyingToMessage = null;
        _replyingToDecryptedText = '';
      });

      FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id).update({
        'typing_status.$uid': false,
      });
      
      final encryptedText = EncryptionService.encryptMessage(text, widget.room.id);

      final message = MessageModel(
        id: const Uuid().v4(),
        senderId: uid,
        text: encryptedText,
        timestamp: DateTime.now(),
        isRead: false,
        replyToEncryptedText: replyEncrypted,
        reactions: const {},
      );

      final batch = FirebaseFirestore.instance.batch();
      
      final msgRef = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.room.id)
          .collection('messages')
          .doc(message.id);
          
      batch.set(msgRef, message.toMap());

      final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id);
      batch.update(roomRef, {
        'last_message': encryptedText,
        'last_updated': FieldValue.serverTimestamp(),
        'unread_counts.${widget.otherUserId}': FieldValue.increment(1),
      });

      await batch.commit();

      final currentRoomSnap = await roomRef.get();
      final activeUsers = (currentRoomSnap.data()?['active_users'] as Map<String, dynamic>?) ?? {};
      final isOtherActive = activeUsers[widget.otherUserId] == true;

      if (!isOtherActive) {
        final myUserDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final myName = myUserDoc.data()?['username'] ?? 'User';

        NotificationService().createNotification(
          userId: widget.otherUserId,
          title: myName,
          body: text,
          type: 'new_message',
          relatedItemId: widget.room.itemId,
          data: {'chat_room_id': widget.room.id},
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _markAsResolved() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id);

    // Mark this user as resolved
    await roomRef.update({
      'resolved_by.$uid': true,
    });

    // Check if both participants have now resolved
    final snap = await roomRef.get();
    final resolvedByMap = Map<String, dynamic>.from(
      (snap.data()?['resolved_by'] as Map<String, dynamic>?) ?? {},
    );

    final bothResolved = widget.room.participants
        .every((pid) => resolvedByMap[pid] == true);

    if (bothResolved) {
      // Both parties confirmed — close the room and start the 3-day countdown
      await roomRef.update({
        'status': 'closed',
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3))),
      });

      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.room.itemId)
          .update({'status': 'Resolved'});

      // If this was a claim with a linked lost report, update that original item as resolved too.
      final claimId = snap.data()?['claim_id'] as String?;
      if (claimId != null) {
        final claimDoc = await FirebaseFirestore.instance.collection('claims').doc(claimId).get();
        if (claimDoc.exists) {
          final claimData = claimDoc.data()!;
          final linkedLostReportId = claimData['linked_lost_report_id'] as String? ?? claimData['resolved_lost_report_id'] as String?;
          if (linkedLostReportId != null) {
             await FirebaseFirestore.instance
                 .collection('items')
                 .doc(linkedLostReportId)
                 .update({'status': 'Resolved'});
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Both parties confirmed! Item resolved. Chat will auto-delete in 3 days.'),
          ),
        );
        Navigator.pop(context);
      }
    } else {
      // Waiting for the other party
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as resolved. Waiting for the other party to confirm.'),
          ),
        );
      }
    }
  }

  void _addReaction(MessageModel msg, String emoji) {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    if (msg.reactions[uid] == emoji) {
      FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.room.id)
          .collection('messages')
          .doc(msg.id)
          .update({
            'reactions.$uid': FieldValue.delete()
          });
    } else {
      FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.room.id)
          .collection('messages')
          .doc(msg.id)
          .set({
            'reactions': {uid: emoji}
          }, SetOptions(merge: true));
    }
  }

  void _showMessageReactionsDialog(MessageModel msg) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ["👍", "❤️", "😂", "😮", "😢", "🙏"].map((emoji) => 
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction(msg, emoji);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                )
              ).toList()
            )
          )
        );
      }
    );
  }

  void _showItemDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              if (widget.itemImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.itemImageUrl, 
                    height: 180, 
                    width: double.infinity, 
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Icon(PhosphorIconsRegular.imageBroken, size: 50, color: Colors.grey),
                  ),
                )
              else
                Container(
                  height: 180, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(PhosphorIconsRegular.imageBroken, size: 50, color: Colors.grey),
                ),
              const SizedBox(height: 16),
              Text(widget.itemTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.obsidian)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsRegular.user, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Chatting with ${widget.otherUserName}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsRegular.calendarBlank, size: 16, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text('Started ${DateFormat.yMMMd().format(widget.room.lastUpdated)}', style: TextStyle(color: Colors.indigo.shade900, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUser?.uid ?? '';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: AppColors.obsidian),
        title: GestureDetector(
          onTap: _showItemDetailsBottomSheet,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.otherProfilePicUrl.isNotEmpty ? NetworkImage(widget.otherProfilePicUrl) : null,
                backgroundColor: Colors.grey.shade200,
                child: widget.otherProfilePicUrl.isEmpty ? const Icon(PhosphorIconsRegular.user, color: Colors.grey, size: 20) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.itemTitle, style: const TextStyle(color: AppColors.obsidian, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Tap for details \u2022 with ${widget.otherUserName}', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _isClosed,
            builder: (context, closed, _) {
              if (closed) return const SizedBox.shrink();
              return ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: _resolvedBy,
                builder: (context, resolvedByMap, _) {
                  final uid = _authService.currentUser?.uid ?? '';
                  // Hide button once this user has already resolved
                  if (resolvedByMap[uid] == true) return const SizedBox.shrink();
                  return TextButton.icon(
                    onPressed: () {
                      showAppConfirmationDialog<bool>(
                        context: context,
                        title: 'Mark as Resolved?',
                        message: 'Once both parties confirm, the item will be marked Resolved and this chat will auto-delete in 3 days.',
                        confirmText: 'Confirm',
                        cancelText: 'Cancel',
                        confirmColor: Colors.green,
                      ).then((confirmed) {
                        if (confirmed == true) _markAsResolved();
                      });
                    },
                    icon: const Icon(PhosphorIconsRegular.checkCircle, color: Colors.green),
                    label: const Text('Resolve', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner — shows resolve state dynamically
          ValueListenableBuilder<bool>(
            valueListenable: _isClosed,
            builder: (context, closed, _) {
              return ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: _resolvedBy,
                builder: (context, resolvedByMap, _) {
                  final uid = _authService.currentUser?.uid ?? '';
                  final iHaveResolved = resolvedByMap[uid] == true;
                  final otherHasResolved = resolvedByMap[widget.otherUserId] == true;

                  if (closed) {
                    // Both confirmed — fully resolved
                    return Container(
                      width: double.infinity,
                      color: Colors.green.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: const Row(
                        children: [
                          Icon(PhosphorIconsRegular.checkCircle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Case Resolved. This chat will auto-delete in 3 days.',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (iHaveResolved && !otherHasResolved) {
                    // I've resolved — waiting for the other party
                    return Container(
                      width: double.infinity,
                      color: Colors.orange.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.clock, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You've marked this as resolved. Waiting for ${widget.otherUserName} to confirm.",
                              style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!iHaveResolved && otherHasResolved) {
                    // Other party has resolved — nudge me
                    return Container(
                      width: double.infinity,
                      color: Colors.blue.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.info, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.otherUserName} has marked this as resolved. Press Resolve to confirm.',
                              style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              );
            },
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: FoundItLoadingIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Say hi!', style: TextStyle(color: Colors.grey, fontSize: 16)));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msgData = docs[index].data() as Map<String, dynamic>;
                    final msg = MessageModel.fromMap(docs[index].id, msgData);
                    final isMe = msg.senderId == currentUserId;
                    
                    final decryptedText = EncryptionService.decryptMessage(msg.text, widget.room.id);
                    final decryptedReplyText = msg.replyToEncryptedText.isNotEmpty 
                        ? EncryptionService.decryptMessage(msg.replyToEncryptedText, widget.room.id) 
                        : '';

                    if (!isMe && !msg.isRead) {
                      FirebaseFirestore.instance
                          .collection('chat_rooms')
                          .doc(widget.room.id)
                          .collection('messages')
                          .doc(msg.id)
                          .update({'is_read': true});
                    }

                    Widget renderReactions() {
                      if (msg.reactions.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: msg.reactions.values.toSet().map((emoji) {
                            int count = msg.reactions.values.where((e) => e == emoji).length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(emoji.toString(), style: const TextStyle(fontSize: 14)),
                                  if (count > 1) 
                                    Padding(
                                      padding: const EdgeInsets.only(left: 2),
                                      child: Text(count.toString(), style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                    )
                                ],
                              ),
                            );
                          }).toList()
                        )
                      );
                    }

                    return Slidable(
                      key: ValueKey(msg.id),
                      startActionPane: isMe ? null : ActionPane(
                        motion: const ScrollMotion(),
                        dismissible: DismissiblePane(
                          onDismissed: () {},
                          confirmDismiss: () async {
                            setState(() {
                              _replyingToMessage = msg;
                              _replyingToDecryptedText = decryptedText;
                              if (!_showEmojiKeyboard) _focusNode.requestFocus();
                            });
                            return false;
                          },
                        ),
                        children: [
                          SlidableAction(
                            onPressed: (_) {
                              setState(() {
                                _replyingToMessage = msg;
                                _replyingToDecryptedText = decryptedText;
                                if (!_showEmojiKeyboard) _focusNode.requestFocus();
                              });
                            },
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.indigo,
                            icon: PhosphorIconsRegular.arrowBendUpLeft,
                            label: 'Reply',
                          ),
                        ],
                      ),
                      endActionPane: !isMe ? null : ActionPane(
                        motion: const ScrollMotion(),
                        dismissible: DismissiblePane(
                          onDismissed: () {},
                          confirmDismiss: () async {
                            setState(() {
                              _replyingToMessage = msg;
                              _replyingToDecryptedText = decryptedText;
                              if (!_showEmojiKeyboard) _focusNode.requestFocus();
                            });
                            return false;
                          },
                        ),
                        children: [
                          SlidableAction(
                            onPressed: (_) {
                              setState(() {
                                _replyingToMessage = msg;
                                _replyingToDecryptedText = decryptedText;
                                if (!_showEmojiKeyboard) _focusNode.requestFocus();
                              });
                            },
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.indigo,
                            icon: PhosphorIconsRegular.arrowBendUpLeft,
                            label: 'Reply',
                          ),
                        ],
                      ),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _showMessageReactionsDialog(msg),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: isMe ? Alignment.bottomRight : Alignment.bottomLeft,
                            children: [
                              Container(
                                margin: EdgeInsets.only(bottom: 12, left: isMe ? 40 : 0, right: isMe ? 0 : 40),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.indigo : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 20),
                                  ),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (decryptedReplyText.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.indigo.shade400 : Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border(left: BorderSide(color: isMe ? Colors.indigo.shade200 : Colors.indigo, width: 4))
                                        ),
                                        child: Text(
                                          decryptedReplyText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: isMe ? Colors.white70 : AppColors.obsidian, fontSize: 13, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    Text(decryptedText, style: TextStyle(color: isMe ? Colors.white : AppColors.obsidian, fontSize: 15)),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          DateFormat('jm').format(msg.timestamp),
                                          style: TextStyle(color: isMe ? Colors.indigo.shade100 : Colors.grey.shade500, fontSize: 10),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          Icon(PhosphorIconsRegular.checks, size: 14, color: msg.isRead ? Colors.lightBlueAccent : Colors.white54),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                child: renderReactions(),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: _isOtherTyping,
            builder: (context, isTyping, child) {
              if (!isTyping) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(left: 16, bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${widget.otherUserName} is typing', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      const SpinKitThreeBounce(color: Colors.indigo, size: 12),
                    ],
                  ),
                ),
              );
            }
          ),

          ValueListenableBuilder<bool>(
            valueListenable: _isClosed,
            builder: (context, closed, child) {
              if (closed) return const SizedBox.shrink();
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      if (_replyingToMessage != null)
                        Container(
                          color: Colors.grey.shade50,
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
                          child: Row(
                            children: [
                              const Icon(PhosphorIconsRegular.arrowBendUpLeft, size: 18, color: Colors.indigo),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Replying to ${_replyingToMessage!.senderId == currentUserId ? "Yourself" : widget.otherUserName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                                    const SizedBox(height: 2),
                                    Text(_replyingToDecryptedText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(PhosphorIconsRegular.x, size: 20),
                                onPressed: () => setState(() {
                                  _replyingToMessage = null;
                                  _replyingToDecryptedText = '';
                                }),
                              )
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(_showEmojiKeyboard ? PhosphorIconsRegular.keyboard : PhosphorIconsRegular.smiley, color: Colors.grey.shade600),
                              onPressed: _onEmojiButtonPressed,
                            ),
                            Expanded(
                              child: TextField(
                                focusNode: _focusNode,
                                controller: _msgController,
                                onTap: () {
                                  if (_showEmojiKeyboard) {
                                    setState(() => _showEmojiKeyboard = false);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Secure message...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF3F4F6),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                              child: IconButton(
                                icon: _isSending 
                                  ? const SizedBox(width: 20, height: 20, child: FoundItLoadingIndicator(size: 16, color: Colors.white)) 
                                  : const Icon(PhosphorIconsRegular.paperPlaneRight, color: Colors.white, size: 20),
                                onPressed: _isSending ? null : _sendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showEmojiKeyboard)
                        SizedBox(
                          height: 250,
                          child: EmojiPicker(
                            textEditingController: _msgController,
                          ),
                        )
                    ],
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}
