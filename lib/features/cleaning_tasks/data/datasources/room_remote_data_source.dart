import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/room_dto.dart';

abstract class IRoomRemoteDataSource {
  Future<List<RoomDto>> fetchRooms({String? householdId});
  Stream<List<RoomDto>> watchRoomsRealtime({String? householdId});
  Future<void> upsertRoom(RoomDto room);
  Future<void> updateCleanlinessScore(String roomId, int score);
  Future<void> deleteRoom(String roomId);
}

class RoomRemoteDataSource implements IRoomRemoteDataSource {
  final SupabaseClient? _client;

  RoomRemoteDataSource(this._client);

  @override
  Future<List<RoomDto>> fetchRooms({String? householdId}) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('Room').select();
      if (householdId != null) {
        query = query.eq('household_id', householdId);
      }
      final response = await query;
      return (response as List).map((e) => RoomDto.fromJson(e)).toList();
    } catch (e) {
      throw ServerException('Nem sikerült lekérni a szobákat: $e');
    }
  }

  @override
  Stream<List<RoomDto>> watchRoomsRealtime({String? householdId}) {
    final client = _client;
    if (client == null) return Stream.value([]);

    try {
      final streamBuilder = client.from('Room').stream(primaryKey: ['id']);
      if (householdId != null) {
        return streamBuilder
            .eq('household_id', householdId)
            .map((rows) => rows.map((e) => RoomDto.fromJson(e)).toList());
      }
      return streamBuilder.map((rows) => rows.map((e) => RoomDto.fromJson(e)).toList());
    } catch (e) {
      return Stream.error(ServerException('Realtime hiba (Room): $e'));
    }
  }

  @override
  Future<void> upsertRoom(RoomDto room) async {
    final client = _client;
    if (client == null) return;

    try {
      // Biztosítjuk a hivatkozott háztartás létezését (FK constraint védelem)
      await client.from('Household').upsert({
        'id': room.householdId,
        'name': 'Családi Otthon',
      });
      await client.from('Room').upsert(room.toJson());
    } catch (e) {
      throw ServerException('Hiba történt a szoba mentésekor: $e');
    }
  }

  @override
  Future<void> updateCleanlinessScore(String roomId, int score) async {
    final client = _client;
    if (client == null) return;

    try {
      await client
          .from('Room')
          .update({'cleanliness_score': score, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', roomId);
    } catch (e) {
      throw ServerException('Hiba a tisztasági pontszám frissítésekor: $e');
    }
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('Room').delete().eq('id', roomId);
    } catch (e) {
      throw ServerException('Hiba a szoba törlésekor: $e');
    }
  }
}
