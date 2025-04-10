import 'package:flutter/material.dart';

class AuthViewModel extends ChangeNotifier {
  String _email = '';
  String _password = '';
  String _name = '';
  DateTime? _birthday;
  String _phoneNumber = '';

  // Getters
  String get email => _email;
  String get password => _password;
  String get name => _name;
  DateTime? get birthday => _birthday;
  String get phoneNumber => _phoneNumber;

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

  void clearUserData() {
    _email = '';
    _password = '';
    _name = '';
    _birthday = null;
    _phoneNumber = '';
    notifyListeners();
  }
}
