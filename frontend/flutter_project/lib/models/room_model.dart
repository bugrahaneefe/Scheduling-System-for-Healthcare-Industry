import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String name;
  final String description;

  RoomModel({required this.id, required this.name, required this.description});

  factory RoomModel.fromMap(String id, Map<String, dynamic> map) {
    return RoomModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
    );
  }
}
