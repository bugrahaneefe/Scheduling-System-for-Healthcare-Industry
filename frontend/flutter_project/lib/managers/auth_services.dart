import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project491/utils/app_localizations.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
    final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'name': name,
      'email': email,
      'title': title,
      'birthday': birthday,
      'phoneNumber': phoneNumber,
      'rooms': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  /// Google sign-in
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
    if (gUser == null) return null;

    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    final userCredential = await firebaseAuth.signInWithCredential(credential);
    await _createUserDocIfNeeded(userCredential.user);
    return userCredential;
  }

  /// Apple sign-in
  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    if (appleCredential.identityToken == null) {
      throw FirebaseAuthException(
        code: 'MISSING_IDENTITY_TOKEN',
        message: 'Apple Sign-In failed: No identity token returned.',
      );
    }

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await firebaseAuth.signInWithCredential(
      oauthCredential,
    );
    final user = userCredential.user;

    if (user != null) {
      final fallbackEmail =
          user.email ?? '${user.uid}@privaterelay.appleid.com';
      final displayName =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
              .trim();

      await _createUserDocIfNeeded(
        user,
        fallbackEmail: fallbackEmail,
        fallbackName: displayName,
      );
    }

    return userCredential;
  }

  /// Create user Firestore document if it doesn’t exist
  Future<void> _createUserDocIfNeeded(
    User? user, {
    String? fallbackEmail,
    String? fallbackName,
  }) async {
    if (user == null) return;

    final doc = _firestore.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'name':
            fallbackName ??
            user.displayName ??
            L.instance.get('enterYourNamePrompt'),
        'email': fallbackEmail ?? user.email ?? '',
        'title': '',
        'birthday': DateTime(1900, 1, 1),
        'phoneNumber': user.phoneNumber ?? '',
        'rooms': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> updateUserProfile({
    required String name,
    required String title,
    required String phoneNumber,
    required DateTime birthday,
  }) async {
    final user = firebaseAuth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'title': title,
        'phoneNumber': phoneNumber,
        'birthday': birthday,
      });
    }
  }

  Future<void> resetPassword(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      throw Exception('Please enter a valid email address');
    }

    try {
      await firebaseAuth.sendPasswordResetEmail(email: email.trim());
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
