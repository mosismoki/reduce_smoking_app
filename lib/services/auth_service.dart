// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password,
    );
    await cred.user?.updateDisplayName(profile['displayName'] as String? ?? '');
    await _saveUserProfile(cred.user!.uid, {
      'email': email,
      'provider': 'password',
      ...profile,
    });
    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<UserCredential> signInWithGoogle({
    Map<String, dynamic>? extraProfile,
  }) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);

    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      await _saveUserProfile(cred.user!.uid, {
        'email': cred.user!.email,
        'displayName': cred.user!.displayName ?? '',
        'provider': 'google',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (extraProfile != null) ...extraProfile,
      });
    }
    return cred;
  }

  Future<void> _saveUserProfile(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isUsernameAvailable(String username) async {
    final q = await _db
        .collection('users')
        .where('usernameLower', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }
}
