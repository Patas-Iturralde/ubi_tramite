enum UserRole {
  admin,
  standard,
  premium,
  advisor,
}

UserRole parseUserRole(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'admin':
      return UserRole.admin;
    case 'premium':
      return UserRole.premium;
    case 'advisor':
      return UserRole.advisor;
    case 'standard':
    default:
      return UserRole.standard;
  }
}

String roleToString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'admin';
    case UserRole.premium:
      return 'premium';
    case UserRole.advisor:
      return 'advisor';
    case UserRole.standard:
      return 'standard';
  }
}


