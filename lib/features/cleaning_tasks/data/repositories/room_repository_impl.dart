import '../../domain/models/room.dart';
import '../../domain/repositories/i_room_repository.dart';
import '../datasources/room_remote_data_source.dart';
import '../models/room_dto.dart';

class RoomRepositoryImpl implements IRoomRepository {
  final IRoomRemoteDataSource remoteDataSource;

  RoomRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Room>> getRooms({String? householdId}) async {
    final dtos = await remoteDataSource.fetchRooms(householdId: householdId);
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Stream<List<Room>> watchRooms({String? householdId}) {
    return remoteDataSource
        .watchRoomsRealtime(householdId: householdId)
        .map((dtos) => dtos.map((dto) => dto.toDomain()).toList());
  }

  @override
  Future<void> saveRoom(Room room) async {
    await remoteDataSource.upsertRoom(RoomDto.fromDomain(room));
  }

  @override
  Future<void> updateCleanlinessScore(String roomId, int score) async {
    await remoteDataSource.updateCleanlinessScore(roomId, score);
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    await remoteDataSource.deleteRoom(roomId);
  }
}
