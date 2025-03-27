// lib/viewmodels/auth_viewmodel.dart

import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // For future Firebase usage

class AuthViewModel extends ChangeNotifier {
  // Example placeholders for Firebase usage:
  // final FirebaseAuth _auth = FirebaseAuth.instance; // commented out for now

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

  // Placeholder for sign-in logic
  // Future<void> signIn() async {
  //   // Use FirebaseAuth to sign in:
  //   // await _auth.signInWithEmailAndPassword(email: _email, password: _password);
  // }

  // Placeholder for sign-up logic
  // Future<void> signUp() async {
  //   // Use FirebaseAuth to sign up:
  //   // await _auth.createUserWithEmailAndPassword(email: _email, password: _password);
  // }
}
