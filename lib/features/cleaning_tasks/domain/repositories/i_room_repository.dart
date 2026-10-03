import '../models/room.dart';

abstract class IRoomRepository {
  Future<List<Room>> getRooms({String? householdId});
  Stream<List<Room>> watchRooms({String? householdId});
  Future<void> saveRoom(Room room);
  Future<void> updateCleanlinessScore(String roomId, int score);
  Future<void> deleteRoom(String roomId);
}
