import 'user_role.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final UserRole role;

  const AppUser({required this.uid, required this.email, required this.displayName, required this.role});

  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      uid: (data['uid'] as String?) ?? '',
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      role: parseUserRole(data['role'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': roleToString(role),
    };
  }
}


