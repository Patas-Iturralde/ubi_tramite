import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<UserCredential> registerWithEmail(
    String email,
    String password, {
    UserRole initialRole = UserRole.standard,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDoc(cred.user!, initialRole: initialRole);
    return cred;
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<void> _ensureUserDoc(User user, {UserRole initialRole = UserRole.standard}) async {
    final doc = _db.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'uid': user.uid,
        'email': user.email,
        'role': roleToString(initialRole),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<UserRole> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return parseUserRole(doc.data()?['role'] as String?);
  }
}



