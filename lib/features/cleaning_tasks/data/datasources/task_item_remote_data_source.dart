import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/task_item_dto.dart';

abstract class ITaskItemRemoteDataSource {
  Future<List<TaskItemDto>> fetchTasks({String? householdId});
  Stream<List<TaskItemDto>> watchTasksRealtime({String? householdId});
  Future<void> upsertTask(TaskItemDto task);
  Future<void> updateTaskStatus(String taskId, String status);
  Future<void> deleteTask(String taskId);
}

class TaskItemRemoteDataSource implements ITaskItemRemoteDataSource {
  final SupabaseClient? _client;

  TaskItemRemoteDataSource(this._client);

  @override
  Future<List<TaskItemDto>> fetchTasks({String? householdId}) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('Task').select();
      if (householdId != null) {
        query = query.eq('household_id', householdId);
      }
      final response = await query;
      return (response as List).map((e) => TaskItemDto.fromJson(e)).toList();
    } catch (e) {
      throw ServerException('Nem sikerült lekérni a feladatokat: $e');
    }
  }

  @override
  Stream<List<TaskItemDto>> watchTasksRealtime({String? householdId}) {
    final client = _client;
    if (client == null) return Stream.value([]);

    try {
      final streamBuilder = client.from('Task').stream(primaryKey: ['id']);
      if (householdId != null) {
        return streamBuilder
            .eq('household_id', householdId)
            .map((rows) => rows.map((e) => TaskItemDto.fromJson(e)).toList());
      }
      return streamBuilder.map((rows) => rows.map((e) => TaskItemDto.fromJson(e)).toList());
    } catch (e) {
      return Stream.error(ServerException('Realtime hiba (Task): $e'));
    }
  }

  @override
  Future<void> upsertTask(TaskItemDto task) async {
    final client = _client;
    if (client == null) return;

    try {
      // Biztosítjuk a hivatkozott háztartás létezését (FK constraint védelem)
      await client.from('Household').upsert({
        'id': task.householdId,
        'name': 'Családi Otthon',
      });
      await client.from('Task').upsert(task.toJson());
    } catch (e) {
      throw ServerException('Hiba történt a feladat mentésekor: $e');
    }
  }

  @override
  Future<void> updateTaskStatus(String taskId, String status) async {
    final client = _client;
    if (client == null) return;

    try {
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == 'completed' || status == 'verified') {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }
      await client.from('Task').update(updates).eq('id', taskId);
    } catch (e) {
      throw ServerException('Hiba a feladat státuszának frissítésekor: $e');
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('Task').delete().eq('id', taskId);
    } catch (e) {
      throw ServerException('Hiba a feladat törlésekor: $e');
    }
  }
}
