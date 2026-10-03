import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';

/// Representation of a family member in the household
class FamilyMember {
  final String id;
  final String name;
  final String role; // 'parent' or 'child'
  final int points;
  final String avatar;
  final String email;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    this.points = 0,
    required this.avatar,
    required this.email,
  });

  bool get isParent => role == 'parent' || role == 'admin';
  bool get isChild => role == 'child';
}

/// Household members notifier (Riverpod 3)
class HouseholdMembersNotifier extends Notifier<List<FamilyMember>> {
  @override
  List<FamilyMember> build() => const []; // Empty until loaded from auth/Supabase

  void setMembers(List<FamilyMember> members) => state = members;

  void addPointsToMember(String memberIdOrName, int points) {
    if (points <= 0) return;
    state = [
      for (final m in state)
        if (m.id == memberIdOrName || m.name.toLowerCase() == memberIdOrName.toLowerCase())
          FamilyMember(
            id: m.id,
            name: m.name,
            role: m.role,
            points: m.points + points,
            avatar: m.avatar,
            email: m.email,
          )
        else
          m,
    ];
  }

  void deductPointsFromMember(String memberIdOrName, int points) {
    if (points <= 0) return;
    state = [
      for (final m in state)
        if (m.id == memberIdOrName || m.name.toLowerCase() == memberIdOrName.toLowerCase())
          FamilyMember(
            id: m.id,
            name: m.name,
            role: m.role,
            points: (m.points - points).clamp(0, 999999),
            avatar: m.avatar,
            email: m.email,
          )
        else
          m,
    ];
  }
}

final householdMembersProvider =
    NotifierProvider<HouseholdMembersNotifier, List<FamilyMember>>(
  HouseholdMembersNotifier.new,
);

/// Current active user notifier (Riverpod 3) — set after login
class CurrentUserNotifier extends Notifier<FamilyMember?> {
  @override
  FamilyMember? build() => null; // null until authenticated

  void setUser(FamilyMember user) => state = user;
  void clear() => state = null;

  void addPoints(int points) {
    if (state == null || points <= 0) return;
    state = FamilyMember(
      id: state!.id,
      name: state!.name,
      role: state!.role,
      points: state!.points + points,
      avatar: state!.avatar,
      email: state!.email,
    );
  }

  void deductPoints(int points) {
    if (state == null || points <= 0) return;
    state = FamilyMember(
      id: state!.id,
      name: state!.name,
      role: state!.role,
      points: (state!.points - points).clamp(0, 999999),
      avatar: state!.avatar,
      email: state!.email,
    );
  }
}

final currentUserProvider =
    NotifierProvider<CurrentUserNotifier, FamilyMember?>(
  CurrentUserNotifier.new,
);

/// Active Household ID provider extracted from auth state
final currentHouseholdIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).householdId;
});

/// Selected person filter notifier on the Tasks tab (null = All)
class SelectedTaskPersonFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? filter) => state = filter;
}

final selectedTaskPersonFilterProvider =
    NotifierProvider<SelectedTaskPersonFilterNotifier, String?>(
  SelectedTaskPersonFilterNotifier.new,
);

/// Helper function to resolve assignee name from ID or name string
String resolveAssigneeName(String? rawAssignee, List<FamilyMember> members) {
  if (rawAssignee == null || rawAssignee.trim().isEmpty) {
    return 'Unassigned';
  }
  for (final m in members) {
    if (m.id == rawAssignee || m.name.toLowerCase() == rawAssignee.toLowerCase()) {
      return m.name;
    }
  }
  return rawAssignee;
}

/// Helper function to resolve assignee avatar
String resolveAssigneeAvatar(String? rawAssignee, List<FamilyMember> members) {
  if (rawAssignee == null || rawAssignee.trim().isEmpty) {
    return '👤';
  }
  for (final m in members) {
    if (m.id == rawAssignee || m.name.toLowerCase() == rawAssignee.toLowerCase()) {
      return m.avatar;
    }
  }
  return '👤';
}
