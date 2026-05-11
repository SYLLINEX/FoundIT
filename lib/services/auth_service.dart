import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../main.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // User stream to keep track of authentication state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  Future<bool> isAdminUser([String? uid]) async {
    final resolvedUid = uid ?? _auth.currentUser?.uid;
    if (resolvedUid == null || resolvedUid.isEmpty) return false;

    try {
      // Delay briefly to allow auth token propagation after initial sign in
      await Future.delayed(const Duration(milliseconds: 350));
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(resolvedUid)
          .get();

      if (!userDoc.exists) return false;
      final data = userDoc.data() ?? {};
      return (data['isAdmin'] ?? false) == true ||
          (data['role']?.toString().toLowerCase() == 'admin');
    } catch (_) {
      return false;
    }
  }

  // Sign up with Email and Password
  Future<UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password, {
    String name = '',
    String phone = '',
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Automatically send verification email upon sign up
      await userCredential.user?.sendEmailVerification();

      // Create standard user profile in Firestore
      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'username': name,
              'email': email,
              'role': 'user',
              'isAdmin': false,
              'matric_no': '',
              'phone_num': phone,
              'profile_img': '',
              'created_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Sign in with Google (Checks if user exists first)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // If the user was just created, it means they didn't exist before!
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        // Delete the newly created user because we only allow existing users to sign in here
        await userCredential.user?.delete();
        await _googleSignIn.signOut();
        throw Exception('Account not found. Please sign up first.');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
          'An account already exists with the same email address but different sign-in credentials.',
        );
      }
      rethrow;
    } catch (e) {
      // Throw the exact message if it's the custom Exception we threw above
      if (e.toString().contains('Account not found')) {
        rethrow;
      }
      throw Exception(
        'An error occurred during Google Sign-In: ${e.toString()}',
      );
    }
  }

  // Google Sign Up
  Future<UserCredential?> signUpWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // If the user already existed, signing in with credential will return isNewUser = false
      if (!(userCredential.additionalUserInfo?.isNewUser ?? true)) {
        await _googleSignIn.signOut();
        throw Exception(
          'An account with this email already exists. Please login instead.',
        );
      }

      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'username': userCredential.user!.displayName ?? '',
              'email': userCredential.user!.email ?? '',
              'role': 'user',
              'isAdmin': false,
              'matric_no': '',
              'phone_num': '',
              'profile_img': userCredential.user!.photoURL ?? '',
              'created_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('already exists')) {
        rethrow;
      }
      throw Exception('An error occurred during Google Sign-Up.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Reset app theme to light mode (default mode for auth screens)
    appThemeNotifier.value = ThemeMode.light;

    // Remove the FCM token from the user's document BEFORE signing out of Firebase.
    // Otherwise, Firestore will block the request because the user is no longer authenticated.
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcm_tokens': FieldValue.arrayRemove([token]),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Error removing FCM token during sign out: $e');
    }

    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
