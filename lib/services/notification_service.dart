import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/app_notification_model.dart';
import '../models/item_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AppNotificationModel>> getUserNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppNotificationModel.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedItemId,
    Map<String, dynamic> data = const {},
  }) async {
    await _firestore.collection('notifications').add({
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'related_item_id': relatedItemId,
      'data': data,
    });
  }

  Future<void> notifyAdmins({
    required String title,
    required String body,
    required String type,
    String? relatedItemId,
    Map<String, dynamic> data = const {},
  }) async {
    final adminUsers = await _firestore
        .collection('users')
        .where('isAdmin', isEqualTo: true)
        .get();

    for (final doc in adminUsers.docs) {
      await createNotification(
        userId: doc.id,
        title: title,
        body: body,
        type: type,
        relatedItemId: relatedItemId,
        data: data,
      );
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'is_read': true,
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final unread = await _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }

  Future<void> notifyNearbyUsersForReport({
    required ItemModel report,
    required double radiusMeters,
  }) async {
    if (report.location == null) return;

    final oppositeType = report.postType.toLowerCase() == 'lost'
        ? 'Found'
        : 'Lost';
    final itemSnapshot = await _firestore
        .collection('items')
        .where('post_type', isEqualTo: oppositeType)
        .get();

    for (final doc in itemSnapshot.docs) {
      final other = ItemModel.fromMap(doc.id, doc.data());
      if (other.location == null) continue;
      if (other.userId == report.userId) continue;

      final status = other.status.toLowerCase();
      final isVisible = status == 'open' || status == 'active';
      if (!isVisible) continue;

      final distance = Geolocator.distanceBetween(
        report.location!.latitude,
        report.location!.longitude,
        other.location!.latitude,
        other.location!.longitude,
      );

      if (distance <= radiusMeters) {
        await createNotification(
          userId: other.userId,
          title: 'Nearby ${report.postType.toLowerCase()} report',
          body:
              'A ${report.postType.toLowerCase()} item report was posted within ${radiusMeters.toStringAsFixed(0)}m of your area.',
          type: 'nearby_report',
          relatedItemId: report.itemId,
          data: {
            'distance_m': distance,
            'post_type': report.postType,
            'title': report.title,
          },
        );
      }
    }
  }
}
