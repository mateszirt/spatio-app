import '../../domain/models/task_item.dart';
import '../../domain/repositories/i_task_item_repository.dart';
import '../datasources/task_item_remote_data_source.dart';
import '../models/task_item_dto.dart';

class TaskItemRepositoryImpl implements ITaskItemRepository {
  final ITaskItemRemoteDataSource remoteDataSource;

  TaskItemRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<TaskItem>> getTasks({String? householdId}) async {
    final dtos = await remoteDataSource.fetchTasks(householdId: householdId);
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Stream<List<TaskItem>> watchTasks({String? householdId}) {
    return remoteDataSource
        .watchTasksRealtime(householdId: householdId)
        .map((dtos) => dtos.map((dto) => dto.toDomain()).toList());
  }

  @override
  Future<void> saveTask(TaskItem task) async {
    await remoteDataSource.upsertTask(TaskItemDto.fromDomain(task));
  }

  @override
  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    await remoteDataSource.updateTaskStatus(taskId, status.value);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await remoteDataSource.deleteTask(taskId);
  }
}
