import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String claimId;
  final String itemId;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastUpdated;
  final String status;
  final DateTime? expiresAt;
  final Map<String, dynamic> typingStatus;
  final Map<String, dynamic> unreadCounts;

  ChatRoomModel({
    required this.id,
    required this.claimId,
    required this.itemId,
    required this.participants,
    required this.lastMessage,
    required this.lastUpdated,
    required this.status,
    this.expiresAt,
    this.typingStatus = const {},
    this.unreadCounts = const {},
  });

  factory ChatRoomModel.fromMap(String documentId, Map<String, dynamic> data) {
    return ChatRoomModel(
      id: documentId,
      claimId: data['claim_id'] ?? '',
      itemId: data['item_id'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['last_message'] ?? '',
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'active',
      expiresAt: (data['expires_at'] as Timestamp?)?.toDate(),
      typingStatus: data['typing_status'] ?? {},
      unreadCounts: data['unread_counts'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'claim_id': claimId,
      'item_id': itemId,
      'participants': participants,
      'last_message': lastMessage,
      'last_updated': Timestamp.fromDate(lastUpdated),
      'status': status,
      if (expiresAt != null) 'expires_at': Timestamp.fromDate(expiresAt!),
      'typing_status': typingStatus,
      'unread_counts': unreadCounts,
    };
  }
}
