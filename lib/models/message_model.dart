import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String replyToEncryptedText;
  final Map<String, dynamic> reactions;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.replyToEncryptedText = '',
    this.reactions = const {},
  });

  factory MessageModel.fromMap(String documentId, Map<String, dynamic> data) {
    return MessageModel(
      id: documentId,
      senderId: data['sender_id'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['is_read'] ?? false,
      replyToEncryptedText: data['reply_to_encrypted_text'] ?? '',
      reactions: data['reactions'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'is_read': isRead,
      'reply_to_encrypted_text': replyToEncryptedText,
      'reactions': reactions,
    };
  }
}
