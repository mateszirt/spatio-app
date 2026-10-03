enum UserRole {
  admin,
  child;

  static UserRole fromString(String val) {
    return val.toLowerCase() == 'admin' ? UserRole.admin : UserRole.child;
  }
}

/// Felhasználói entitás (szerepkörök: admin, child)
class AppUser {
  final String id;
  final String householdId;
  final String name;
  final String? email;
  final UserRole role;
  final String? avatarUrl;
  final int pointsTotal;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.householdId,
    required this.name,
    this.email,
    required this.role,
    this.avatarUrl,
    this.pointsTotal = 0,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isChild => role == UserRole.child;
}
