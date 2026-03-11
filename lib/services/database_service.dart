import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all items to show on the map
  Stream<List<ItemModel>> getItemsStream() {
    return _firestore.collection('items').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ItemModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Add a new item with location
  Future<void> addItem(ItemModel item) async {
    await _firestore.collection('items').add(item.toMap());
  }
}
