import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String id;
  final String title;
  final String description;
  final String type; // 'lost' or 'found'
  final GeoPoint location;

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.location,
  });

  factory ItemModel.fromMap(String id, Map<String, dynamic> data) {
    return ItemModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'lost',
      location: data['location'] as GeoPoint,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'location': location,
    };
  }
}
