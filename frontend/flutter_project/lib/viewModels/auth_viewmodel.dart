import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../managers/auth_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthViewModel extends ChangeNotifier {
  String _email = '';
  String _password = '';
  String _name = '';
  DateTime? _birthday;
  String _phoneNumber = '';
  String _title = '';
  List<String> _rooms = [];

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Getters
  String get email => _email;
  String get password => _password;
  String get name => _name;
  DateTime? get birthday => _birthday;
  String get phoneNumber => _phoneNumber;
  String get title => _title;
  List<String> get rooms => _rooms;

  // Setters
  void updateEmail(String value) {
    _email = value;
    notifyListeners();
  }

  void updatePassword(String value) {
    _password = value;
    notifyListeners();
  }

  void updateName(String value) {
    _name = value;
    notifyListeners();
  }

  void updateBirthday(DateTime value) {
    _birthday = value;
    notifyListeners();
  }

  void updatePhoneNumber(String value) {
    _phoneNumber = value;
    notifyListeners();
  }

  void updateTitle(String value) {
    _title = value;
    notifyListeners();
  }

  void clearUserData() {
    _email = '';
    _password = '';
    _name = '';
    _birthday = null;
    _phoneNumber = '';
    _title = '';
    _rooms = [];
    notifyListeners();
  }

  Future<void> loadCurrentUser() async {
    final user = authService.value.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!);
        notifyListeners();
      }
    }
  }
}
