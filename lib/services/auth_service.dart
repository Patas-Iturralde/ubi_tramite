import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';
import '../models/app_user.dart';

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
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user!.updateDisplayName(displayName);
    }
    await _ensureUserDoc(cred.user!, initialRole: initialRole, displayName: displayName);
    return cred;
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<void> _ensureUserDoc(User user, {UserRole initialRole = UserRole.standard, String? displayName}) async {
    final doc = _db.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName,
        'role': roleToString(initialRole),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<UserRole> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return parseUserRole(doc.data()?['role'] as String?);
  }

  static Stream<List<AppUser>> usersStream() {
    return _db.collection('users').orderBy('createdAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => AppUser.fromMap(d.data())).toList(),
    );
  }

  static Future<void> updateUserRole({required String uid, required UserRole role}) async {
    await _db.collection('users').doc(uid).update({'role': roleToString(role)});
  }

  static Future<void> deleteUserDoc({required String uid}) async {
    await _db.collection('users').doc(uid).delete();
  }

  static Future<void> updateDisplayName({required String uid, required String displayName}) async {
    await _db.collection('users').doc(uid).update({'displayName': displayName});
  }
}



