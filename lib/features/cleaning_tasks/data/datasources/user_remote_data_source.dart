import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/models/app_user.dart';

abstract class IUserRemoteDataSource {
  Future<List<AppUser>> fetchUsers(String householdId);

  /// Supabase aggregáció: SUM(points_reward) a befejezett feladatokból
  /// ahol completed_at >= [since] ÉS assigned_to == [userId]
  Future<int> fetchEffortPoints(String userId, {required DateTime since});
}

class UserRemoteDataSource implements IUserRemoteDataSource {
  final SupabaseClient? _client;

  UserRemoteDataSource(this._client);

  @override
  Future<List<AppUser>> fetchUsers(String householdId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('User')
          .select()
          .eq('household_id', householdId);

      return (response as List).map((row) => _rowToUser(row)).toList();
    } catch (e) {
      throw ServerException('Felhasználók lekérési hiba: $e');
    }
  }

  @override
  Future<int> fetchEffortPoints(String userId, {required DateTime since}) async {
    final client = _client;
    if (client == null) return 0;

    try {
      // Supabase aggregáció: completed_at >= since AND assigned_to = userId
      // Az összes befejezett és ellenőrzött feladat pontjait összegezzük
      final response = await client
          .from('Task')
          .select('points_reward')
          .eq('assigned_to', userId)
          .inFilter('status', ['completed', 'verified'])
          .gte('completed_at', since.toIso8601String());

      final rows = response as List;
      final total = rows.fold<int>(
        0,
        (sum, row) => sum + ((row['points_reward'] as num?)?.toInt() ?? 0),
      );
      return total;
    } catch (e) {
      // Effort-pont hiba nem végzetes – visszaadunk 0-t (legkevésbé terhelt)
      return 0;
    }
  }

  // ─── Mapper ───────────────────────────────────────────────────────────────

  static AppUser _rowToUser(Map<String, dynamic> row) {
    return AppUser(
      id: row['id'] as String,
      householdId: row['household_id'] as String,
      name: row['name'] as String? ?? 'Ismeretlen',
      email: row['email'] as String?,
      role: UserRole.fromString(row['role'] as String? ?? 'admin'),
      avatarUrl: row['avatar_url'] as String?,
      pointsTotal: (row['points_total'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
