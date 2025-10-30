import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges();
});

final userRoleProvider = FutureProvider<UserRole>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return UserRole.standard;
  return AuthService.getUserRole(user.uid);
});



