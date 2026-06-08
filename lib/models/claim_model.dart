import 'package:cloud_firestore/cloud_firestore.dart';

class ClaimModel {
  final String claimId;
  final String itemId;
  final String claimantId;
  final String ownerId;
  final String proofDesc;
  final String status;
  final DateTime timestamp;
  List<String>? proofImageUrls;
  String? linkedLostReportId;
  double? similarityScore;
  /// 'claim'     — user claims ownership of a FOUND item (existing flow)
  /// 'found_tip' — user reports finding a LOST item (new flow)
  final String claimType;
  List<double>? claimantAiScoreVector;
  List<String>? claimantAiLabels;

  ClaimModel({
    required this.claimId,
    required this.itemId,
    required this.claimantId,
    required this.ownerId,
    required this.proofDesc,
    required this.status,
    required this.timestamp,
    this.proofImageUrls,
    this.linkedLostReportId,
    this.similarityScore,
    this.claimType = 'claim',
    this.claimantAiScoreVector,
    this.claimantAiLabels,
  });

  bool get isFoundTip => claimType == 'found_tip';

  factory ClaimModel.fromMap(String id, Map<String, dynamic> data) {
    return ClaimModel(
      claimId: id,
      itemId: data['item_id'] ?? '',
      claimantId: data['claimant_id'] ?? '',
      ownerId: data['owner_id'] ?? '',
      proofDesc: data['proof_desc'] ?? '',
      status: data['status'] ?? 'Pending',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      proofImageUrls: List<String>.from(data['proof_image_urls'] ?? []),
      linkedLostReportId: data['linked_lost_report_id'],
      similarityScore: (data['similarity_score'] as num?)?.toDouble(),
      claimType: data['claim_type'] ?? 'claim',
      claimantAiScoreVector: (data['claimant_ai_score_vector'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      claimantAiLabels: (data['claimant_ai_labels'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
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
      'proof_image_urls': proofImageUrls ?? [],
      'linked_lost_report_id': linkedLostReportId,
      'similarity_score': similarityScore,
      'claim_type': claimType,
      'claimant_ai_score_vector': claimantAiScoreVector,
      'claimant_ai_labels': claimantAiLabels,
    };
  }
}
