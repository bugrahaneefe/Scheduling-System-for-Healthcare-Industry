import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String userId;
  final String name;
  final bool isHost;

  Participant({required this.userId, required this.name, required this.isHost});

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      isHost: map['isHost'] ?? false,
    );
  }
}

class RoomModel {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final List<Participant> participants;

  RoomModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.participants,
  });

  factory RoomModel.fromMap(String id, Map<String, dynamic> map) {
    return RoomModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      participants:
          (map['participants'] as List<dynamic>)
              .map((p) => Participant.fromMap(p as Map<String, dynamic>))
              .toList(),
    );
  }
}
