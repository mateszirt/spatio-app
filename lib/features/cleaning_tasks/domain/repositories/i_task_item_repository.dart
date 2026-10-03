import '../models/task_item.dart';

abstract class ITaskItemRepository {
  Future<List<TaskItem>> getTasks({String? householdId});
  Stream<List<TaskItem>> watchTasks({String? householdId});
  Future<void> saveTask(TaskItem task);
  Future<void> updateTaskStatus(String taskId, TaskStatus status);
  Future<void> deleteTask(String taskId);
}
