import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String name;
  final String email;
  final String title;
  final DateTime birthday;
  final String phoneNumber;
  final List<String> rooms;

  UserModel({
    required this.name,
    required this.email,
    required this.title,
    required this.birthday,
    required this.phoneNumber,
    required this.rooms,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      title: map['title'] ?? '',
      birthday: (map['birthday'] as Timestamp).toDate(),
      phoneNumber: map['phoneNumber'] ?? '',
      rooms: List<String>.from(map['rooms'] ?? []),
    );
  }
}
