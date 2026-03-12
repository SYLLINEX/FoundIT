import 'package:cloud_firestore/cloud_firestore.dart';

class ClaimModel {
  final String claimId;
  final String itemId;
  final String claimantId;
  final String ownerId;
  final String proofDesc;
  final String status;
  final DateTime timestamp;

  ClaimModel({
    required this.claimId,
    required this.itemId,
    required this.claimantId,
    required this.ownerId,
    required this.proofDesc,
    required this.status,
    required this.timestamp,
  });

  factory ClaimModel.fromMap(String id, Map<String, dynamic> data) {
    return ClaimModel(
      claimId: id,
      itemId: data['item_id'] ?? '',
      claimantId: data['claimant_id'] ?? '',
      ownerId: data['owner_id'] ?? '',
      proofDesc: data['proof_desc'] ?? '',
      status: data['status'] ?? 'Pending',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'claimant_id': claimantId,
      'owner_id': ownerId,
      'proof_desc': proofDesc,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}