import '../models/app_user.dart';

/// Felhasználó-kezelési repository interfész (Clean Architecture)
abstract class IUserRepository {
  /// Egy háztartás összes felhasználójának lekérdezése.
  Future<List<AppUser>> getUsersByHousehold(String householdId);

  /// Egy felhasználó összes befejezett feladatának [points_reward] összege
  /// a [since] dátumtól kezdve.
  ///
  /// A load-balancing algoritmus ezt hívja a 14 napos effort-ablak számításához.
  Future<int> getEffortPoints(String userId, {required DateTime since});
}
