import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../models/item_model.dart';
import '../models/claim_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPublicStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'open' ||
        normalized == 'active' ||
        normalized == 'reserved';
  }

  // Fetch all items to show on the map
  Stream<List<ItemModel>> getItemsStream() {
    return _firestore
        .collection('items')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                return ItemModel.fromMap(doc.id, doc.data());
              })
              .where((item) => _isPublicStatus(item.status))
              .toList();
        });
  }

  // Fetch items for a specific user
  Stream<List<ItemModel>> getUserItemsStream(String userId) {
    return _firestore
        .collection('items')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) {
            return ItemModel.fromMap(doc.id, doc.data());
          }).toList();
          // Sort locally to avoid requiring a composite index in Firestore
          items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return items;
        });
  }

  // Add a new item with location
  Future<String> addItem(ItemModel item) async {
    final Map<String, dynamic> data = item.toMap();
    if (item.location != null) {
      final geoFirePoint = GeoFirePoint(item.location!);
      data['geo'] = geoFirePoint.data;
    }
    final docRef = await _firestore.collection('items').add(data);
    return docRef.id;
  }

  // Fetch items near a point (1km radius default)
  Stream<List<ItemModel>> getItemsWithinRadiusStream(
    GeoPoint centerPoint, {
    double radiusInKm = 1.0,
  }) {
    final center = GeoFirePoint(centerPoint);

    return GeoCollectionReference<Map<String, dynamic>>(
          _firestore.collection('items'),
        )
        .subscribeWithin(
          center: center,
          radiusInKm: radiusInKm,
          field: 'geo',
          geopointFrom: (data) =>
              (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
        )
        .map((snapshots) {
          return snapshots
              .map((doc) => ItemModel.fromMap(doc.id, doc.data()!))
              .where((item) => _isPublicStatus(item.status))
              .toList();
        });
  }

  // Submit a claim
  Future<void> submitClaim(ClaimModel claim) async {
    await _firestore.collection('claims').doc(claim.claimId).set(claim.toMap());
  }

  // Update item
  Future<void> updateItem(String itemId, Map<String, dynamic> data) async {
    await _firestore.collection('items').doc(itemId).update(data);
  }

  // Delete item
  Future<void> deleteItem(String itemId) async {
    await _firestore.collection('items').doc(itemId).delete();
  }
}
