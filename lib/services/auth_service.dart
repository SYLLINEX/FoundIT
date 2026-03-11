import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // User stream to keep track of authentication state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign up with Email and Password
  Future<UserCredential?> signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Automatically send verification email upon sign up
      await userCredential.user?.sendEmailVerification();
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred';
    }
  }

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred';
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
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

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
        throw Exception('An account already exists with the same email address but different sign-in credentials.');
      }
      throw Exception(e.message ?? 'An unknown error occurred during Google Sign-In.');
    } catch (e) {
      // Throw the exact message if it's the custom Exception we threw above
      if (e.toString().contains('Account not found')) {
        rethrow;
      }
      throw Exception('An error occurred during Google Sign-In: ${e.toString()}');
    }
  }

  // Google Sign Up
  Future<UserCredential?> signUpWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // If the user already existed, signing in with credential will return isNewUser = false
      if (!(userCredential.additionalUserInfo?.isNewUser ?? true)) {
        await _googleSignIn.signOut();
        throw Exception('An account with this email already exists. Please login instead.');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to sign up with Google.');
    } catch (e) {
      if (e.toString().contains('already exists')) {
        rethrow;
      }
      throw Exception('An error occurred during Google Sign-Up.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
