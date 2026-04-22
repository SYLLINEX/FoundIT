import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String itemId;
  final String userId;
  final String postType;
  final String category;
  final String title;
  final String description;
  final String imageUrl;
  final GeoPoint? location;
  final String locationName;
  final String status;
  final List<String> aiLabels;
  final List<double> aiScoreVector; // 10-dim probability vector from fine-tuned model
  final DateTime timestamp;
  final DateTime? eventDate; // Actual date lost or found
  final String? specificLocation;
  final String? reporterName;
  final String? manualCategory;

  ItemModel({
    required this.itemId,
    required this.userId,
    required this.postType,
    required this.category,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.location,
    required this.locationName,
    required this.status,
    required this.aiLabels,
    this.aiScoreVector = const [],
    required this.timestamp,
    this.eventDate,
    this.specificLocation,
    this.reporterName,
    this.manualCategory,
  });

  factory ItemModel.fromMap(String id, Map<String, dynamic> data) {
    GeoPoint? parsedLocation = data['location'] as GeoPoint?;
    if (parsedLocation == null && data['geo'] != null && data['geo']['geopoint'] != null) {
      parsedLocation = data['geo']['geopoint'] as GeoPoint?;
    }

    return ItemModel(
      itemId: id,
      userId: data['user_id'] ?? '',
      postType: data['post_type'] ?? 'Lost',
      category: data['category'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image_url'] ?? '',
      location: parsedLocation,
      locationName: data['location_name'] ?? '',
      status: data['status'] ?? 'Active',
      aiLabels: List<String>.from(data['ai_labels'] ?? []),
      aiScoreVector: List<double>.from(
        (data['ai_score_vector'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()),
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventDate: data['event_date'] != null ? (data['event_date'] as Timestamp).toDate() : null,
      specificLocation: data['specific_location'],
      reporterName: data['reporter_name'],
      manualCategory: data['manual_category'],
    );
  }

  /// Returns a copy of this item with [scoreVector] substituted as [aiScoreVector].
  /// Used by claim_item_screen when averaging claimant photo vectors for comparison.
  ItemModel copyWithScoreVector(List<double> scoreVector) {
    return ItemModel(
      itemId: itemId,
      userId: userId,
      postType: postType,
      category: category,
      title: title,
      description: description,
      imageUrl: imageUrl,
      location: location,
      locationName: locationName,
      status: status,
      aiLabels: aiLabels,
      aiScoreVector: scoreVector,
      timestamp: timestamp,
      eventDate: eventDate,
      specificLocation: specificLocation,
      reporterName: reporterName,
      manualCategory: manualCategory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'post_type': postType,
      'category': category,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'location': location,
      'location_name': locationName,
      'status': status,
      'ai_labels': aiLabels,
      'ai_score_vector': aiScoreVector,
      'timestamp': FieldValue.serverTimestamp(),
      if (eventDate != null) 'event_date': Timestamp.fromDate(eventDate!),
      if (specificLocation != null) 'specific_location': specificLocation,
      if (reporterName != null) 'reporter_name': reporterName,
      if (manualCategory != null) 'manual_category': manualCategory,
    };
  }
}
