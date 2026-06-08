import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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
import '../../widgets/theme_aware_shimmer.dart';

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
  final ValueNotifier<Map<String, dynamic>> _cancelRequestedBy = ValueNotifier({});
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
        _cancelRequestedBy.value = Map<String, dynamic>.from(data['cancel_requested_by'] ?? {});
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
      try {
        await roomRef.update({
          'status': 'closed',
          'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3))),
        });

        // Update main item
        final itemRef = FirebaseFirestore.instance.collection('items').doc(widget.room.itemId);
        await itemRef.update({'status': 'Resolved'});

        // Verify update
        final updatedItem = await itemRef.get();
        final newStatus = updatedItem.data()?['status'];
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item status is now: $newStatus')),
          );
        }

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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating item: $e'),
            ),
          );
        }
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

  void _cancelDeal() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(widget.room.id);

    // Mark this user as canceling the deal
    await roomRef.update({
      'cancel_requested_by.$uid': true,
    });

    // Check if both participants have now cancelled
    final snap = await roomRef.get();
    final cancelledByMap = Map<String, dynamic>.from(
      (snap.data()?['cancel_requested_by'] as Map<String, dynamic>?) ?? {},
    );

    final bothCancelled = widget.room.participants
        .every((pid) => cancelledByMap[pid] == true);

    if (bothCancelled) {
      // Both parties confirmed cancellation
      await roomRef.update({
        'status': 'closed',
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3))),
      });

      // Mark item as Resolved since deal was cancelled
      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.room.itemId)
          .update({'status': 'Resolved'});

      // Change claim status to Cancelled if it exists
      final claimId = snap.data()?['claim_id'] as String?;
      if (claimId != null) {
        await FirebaseFirestore.instance.collection('claims').doc(claimId).update({'status': 'Cancelled'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deal cancelled! Item marked as Resolved. Chat will auto-delete in 3 days.'),
          ),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancellation requested. Waiting for the other party to confirm.'),
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
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(30)),
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
    final uid = _authService.currentUser?.uid ?? '';
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
                    placeholder: (context, url) => ThemeAwareShimmer(                      child: Container(color: Colors.white),
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
              Text(widget.itemTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
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
              const SizedBox(height: 24),
              ValueListenableBuilder<bool>(
                valueListenable: _isClosed,
                builder: (context, closed, _) {
                  return ValueListenableBuilder<Map<String, dynamic>>(
                    valueListenable: _resolvedBy,
                    builder: (context, resolvedByMap, _) {
                      return ValueListenableBuilder<Map<String, dynamic>>(
                        valueListenable: _cancelRequestedBy,
                        builder: (context, cancelRequestedByMap, _) {
                          final iHaveResolved = resolvedByMap[uid] == true;
                          final iHaveCancelled = cancelRequestedByMap[uid] == true;
                          final canAct = !closed && !iHaveResolved && !iHaveCancelled;
                          if (!canAct) return const SizedBox.shrink();
                          return Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
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
                                  icon: const Icon(PhosphorIconsRegular.checkCircle, size: 18),
                                  label: const Text('Mark as Resolved'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    showAppConfirmationDialog<bool>(
                                      context: context,
                                      title: 'Cancel Deal?',
                                      message: 'If both parties cancel, the deal is terminated, the claim is cancelled, and the item will be relisted.',
                                      confirmText: 'Cancel Deal',
                                      cancelText: 'Go Back',
                                      confirmColor: Colors.red.shade700,
                                    ).then((confirmed) {
                                      if (confirmed == true) _cancelDeal();
                                    });
                                  },
                                  icon: Icon(PhosphorIconsRegular.xCircle, size: 18, color: Colors.red.shade700),
                                  label: Text('Cancel', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
}

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUser?.uid ?? '';
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 1,
        titleSpacing: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: GestureDetector(
          onTap: _showItemDetailsBottomSheet,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.otherProfilePicUrl.isNotEmpty ? NetworkImage(widget.otherProfilePicUrl) : null,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: widget.otherProfilePicUrl.isEmpty ? const Icon(PhosphorIconsRegular.user, color: Colors.grey, size: 20) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.itemTitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Tap for details \u2022 with ${widget.otherUserName}', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Waiting for approval indicator
          ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: _resolvedBy,
            builder: (context, resolvedByMap, _) {
              return ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: _cancelRequestedBy,
                builder: (context, cancelRequestedByMap, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _isClosed,
                    builder: (context, closed, _) {
                      if (closed) return const SizedBox.shrink();
                      final uid = _authService.currentUser?.uid ?? '';
                      final iHaveResolved = resolvedByMap[uid] == true;
                      final iHaveCancelled = cancelRequestedByMap[uid] == true;
                      
                      if (!iHaveResolved && !iHaveCancelled) return const SizedBox.shrink();
                      
                      final isWaitingForResolution = iHaveResolved;
                      final statusText = isWaitingForResolution 
                          ? 'Waiting for ${widget.otherUserName} to confirm resolution...'
                          : 'Waiting for ${widget.otherUserName} to confirm cancellation...';
                      
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          border: Border(bottom: BorderSide(color: Colors.amber.shade200, width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: SpinKitRing(
                                color: Colors.amber.shade700,
                                lineWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade700,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
           ),
           // Other user waiting for approval indicator
           ValueListenableBuilder<Map<String, dynamic>>(
             valueListenable: _resolvedBy,
             builder: (context, resolvedByMap, _) {
               return ValueListenableBuilder<Map<String, dynamic>>(
                 valueListenable: _cancelRequestedBy,
                 builder: (context, cancelRequestedByMap, _) {
                   return ValueListenableBuilder<bool>(
                     valueListenable: _isClosed,
                     builder: (context, closed, _) {
                       if (closed) return const SizedBox.shrink();
                       final uid = _authService.currentUser?.uid ?? '';
                       final iHaveResolved = resolvedByMap[uid] == true;
                       final iHaveCancelled = cancelRequestedByMap[uid] == true;
                       final otherHasResolved = resolvedByMap[widget.otherUserId] == true;
                       final otherHasCancelled = cancelRequestedByMap[widget.otherUserId] == true;
                       
                       // Show this only if OTHER user has taken action but I haven't
                       if (iHaveResolved || iHaveCancelled) return const SizedBox.shrink();
                       if (!otherHasResolved && !otherHasCancelled) return const SizedBox.shrink();
                       
                       final isOtherWaitingForResolution = otherHasResolved;
                       final statusText = isOtherWaitingForResolution
                           ? '${widget.otherUserName} marked as resolved. Confirm to finalize.'
                           : '${widget.otherUserName} requested to cancel. Confirm to cancel deal.';
                       
                       return Container(
                         width: double.infinity,
                         padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                         decoration: BoxDecoration(
                           color: Colors.blue.shade50,
                           border: Border(bottom: BorderSide(color: Colors.blue.shade200, width: 1)),
                         ),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(
                               PhosphorIconsRegular.info,
                               color: Colors.blue.shade700,
                               size: 16,
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 statusText,
                                 style: TextStyle(
                                   fontSize: 13,
                                   fontWeight: FontWeight.w600,
                                   color: Colors.blue.shade700,
                                 ),
                                 textAlign: TextAlign.center,
                                 maxLines: 2,
                                 overflow: TextOverflow.ellipsis,
                               ),
                             ),
                           ],
                         ),
                       );
                     },
                   );
                 },
               );
             },
           ),
           // Resolved/Cancelled confirmation banner
           ValueListenableBuilder<bool>(
            valueListenable: _isClosed,
            builder: (context, closed, _) {
              if (!closed) return const SizedBox.shrink();
              final uid = _authService.currentUser?.uid ?? '';
              final cancelRequestedByMap = _cancelRequestedBy.value;
              final iHaveCancelled = cancelRequestedByMap[uid] == true;
              final isCancelled = iHaveCancelled;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border(bottom: BorderSide(color: Colors.green.shade200, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsRegular.checkCircle, color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 8),
                     Text(
                       isCancelled
                           ? 'Deal Cancelled — Item marked as Resolved.'
                           : 'Case Resolved — This chat will auto-delete in 3 days.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
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
                          color: Theme.of(context).cardColor,
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
                                  color: isMe ? Colors.indigo : Theme.of(context).cardColor,
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
                                          style: TextStyle(color: isMe ? Colors.white70 : Theme.of(context).colorScheme.onSurface, fontSize: 13, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    Text(decryptedText, style: TextStyle(color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: 15)),
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
                    color: Theme.of(context).cardColor,
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
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      if (_replyingToMessage != null)
                        Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
