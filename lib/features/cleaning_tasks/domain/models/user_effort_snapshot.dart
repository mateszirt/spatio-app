import 'app_user.dart';

/// Egy felhasználó erőfeszítés-összesítője az elmúlt 14 napban.
/// Immutable Value Object – a load-balancing algoritmus bemenete.
class UserEffortSnapshot {
  final String userId;
  final String name;
  final UserRole role;

  /// Az elmúlt 14 napban befejezett feladatok összes [points_reward] összege.
  final int effortPoints;

  const UserEffortSnapshot({
    required this.userId,
    required this.name,
    required this.role,
    required this.effortPoints,
  });

  bool get isAdult => role == UserRole.admin;
  bool get isChild => role == UserRole.child;

  /// Factory: AppUser-ből és egy frissen lekért effortPoints-ból
  factory UserEffortSnapshot.fromUser(AppUser user, {required int effortPoints}) {
    return UserEffortSnapshot(
      userId: user.id,
      name: user.name,
      role: user.role,
      effortPoints: effortPoints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEffortSnapshot &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      'UserEffortSnapshot(userId: $userId, name: $name, effortPoints: $effortPoints)';
}
