import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

ValueNotifier<AuthServices> authService = ValueNotifier(AuthServices());

class AuthServices {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        throw Exception('Kullanıcı bulunamadı veya hesap silinmiş.');
      }
      throw e;
    }
  }

  Future<void> signOut() async {
    try {
      await firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String title,
    required DateTime birthday,
    required String phoneNumber,
  }) async {
    try {
      final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'title': title,
        'birthday': birthday,
        'phoneNumber': phoneNumber,
        'rooms': [], // Initialize empty rooms array
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  /// Google sign-in.
  /// – Creates a Firestore user-document on first login
  /// – Returns the same UserCredential object as e-mail/password sign-in
  Future<UserCredential?> signInWithGoogle() async {
    // 1. Interactive Google sign-in dialog
    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
    if (gUser == null) return null; // user closed the dialog

    // 2. Credentials
    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    // 3. Firebase sign-in
    final userCredential = await firebaseAuth.signInWithCredential(credential);

    // 4. Create user-document on first login
    final user = userCredential.user;
    if (user != null) {
      final doc = _firestore.collection('users').doc(user.uid);
      final snap = await doc.get();
      if (!snap.exists) {
        await doc.set({
          'name': user.displayName ?? '',
          'email': user.email,
          'title': '',
          'birthday': DateTime(1900, 1, 1),
          'phoneNumber': user.phoneNumber ?? '',
          'rooms': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return userCredential;
  }

  Future<void> updateUserProfile({
    required String name,
    required String title,
    required String phoneNumber,
    required DateTime birthday,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': name,
          'title': title,
          'phoneNumber': phoneNumber,
          'birthday': birthday,
        });
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    // Basic email validation
    if (email.isEmpty || !email.contains('@')) {
      throw Exception('Please enter a valid email address');
    }

    try {
      await firebaseAuth.sendPasswordResetEmail(
        email: email.trim(), // Remove any whitespace
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found with this email address');
        case 'invalid-email':
          throw Exception('The email address is invalid');
        case 'too-many-requests':
          throw Exception('Too many requests. Please try again later');
        default:
          throw Exception('Failed to send reset password email: ${e.message}');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }
}
