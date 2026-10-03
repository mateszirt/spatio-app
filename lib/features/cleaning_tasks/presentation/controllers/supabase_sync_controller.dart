import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/id_generator.dart';
import '../../data/datasources/room_remote_data_source.dart';
import '../../data/datasources/task_item_remote_data_source.dart';
import '../../data/repositories/room_repository_impl.dart';
import '../../data/repositories/task_item_repository_impl.dart';
import '../../domain/models/room.dart';
import '../../domain/models/task_item.dart';
import '../../domain/models/furniture_item.dart';
import '../../domain/repositories/i_room_repository.dart';
import '../../domain/repositories/i_task_item_repository.dart';
import 'household_state_provider.dart';
import '../../../../core/services/auth_service.dart';

// --- Room Providers ---

final roomRemoteDataSourceProvider = Provider<IRoomRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return RoomRemoteDataSource(client);
});

final roomRepositoryProvider = Provider<IRoomRepository>((ref) {
  return RoomRepositoryImpl(
    remoteDataSource: ref.watch(roomRemoteDataSourceProvider),
  );
});

/// Real-time offline-first room stream (reads from Drift, filtered by householdId, synced with Supabase)
final roomsRealtimeStreamProvider = StreamProvider<List<Room>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final authState = ref.watch(authProvider);
  return syncService.watchLocalRooms(householdId: authState.householdId);
});

// --- Task Providers ---

final taskItemRemoteDataSourceProvider = Provider<ITaskItemRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TaskItemRemoteDataSource(client);
});

final taskItemRepositoryProvider = Provider<ITaskItemRepository>((ref) {
  return TaskItemRepositoryImpl(
    remoteDataSource: ref.watch(taskItemRemoteDataSourceProvider),
  );
});

/// Real-time offline-first task stream (reads from Drift, filtered by householdId, synced with Supabase)
final tasksRealtimeStreamProvider = StreamProvider<List<TaskItem>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final authState = ref.watch(authProvider);
  return syncService.watchLocalTasks(householdId: authState.householdId);
});

/// Real-time offline-first furniture stream (reads from Drift, filtered by householdId, synced with Supabase)
final furnitureRealtimeStreamProvider = StreamProvider<List<FurnitureItem>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final authState = ref.watch(authProvider);
  return syncService.watchLocalFurnitureItems(householdId: authState.householdId);
});

// --- Realtime / Offline-First Controller Operations ---

class SupabaseSyncController extends Notifier<void> {
  @override
  void build() {
    final authState = ref.watch(authProvider);
    final syncService = ref.watch(syncServiceProvider);

    if (authState.householdId != null && authState.householdId!.isNotEmpty) {
      final hhId = authState.householdId!;
      syncService.onUserChanged = (changedHhId) {
        if (changedHhId == hhId) {
          ref.read(authProvider.notifier).refreshHouseholdMembers();
        }
      };
      syncService.subscribeToHouseholdRealtime(hhId);
      Future.microtask(() => syncService.syncAll(householdId: hhId));
    }
  }

  /// Add a new room
  Future<void> addRoom({
    required String householdId,
    required String name,
    int floor = 1,
    int cleanlinessScore = 100,
  }) async {
    final syncService = ref.read(syncServiceProvider);
    final newRoom = Room(
      id: generateUuid(),
      householdId: householdId,
      name: name,
      floor: floor,
      cleanlinessScore: cleanlinessScore,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await syncService.saveRoom(newRoom);
  }

  /// Save drawn room with immediate local Drift persistence and Supabase sync
  Future<void> saveDrawnRoom(Room room) async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.saveRoom(room);
  }

  /// Delete room (cascades locally and on Supabase)
  Future<void> deleteRoom(String roomId) async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.deleteRoom(roomId);
  }

  /// Update room cleanliness score (0-100)
  Future<void> updateRoomCleanliness(String roomId, int score) async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.updateRoomCleanliness(roomId, score);
  }

  /// Add new task with polymorphic reference (Room or Furniture_Item)
  Future<void> addTask({
    required String householdId,
    required String title,
    String? description,
    required String referenceId,
    required TaskReferenceType referenceType,
    int pointsReward = 10,
    int priority = 3,
    DateTime? dueDate,
    bool isRecurring = false,
    int? repeatIntervalMinutes,
    String? notes,
    String? assignedTo,
  }) async {
    final syncService = ref.read(syncServiceProvider);
    final packedDescription = TaskItem.packDescription(
      priority: priority,
      isRecurring: isRecurring,
      repeatIntervalMinutes: repeatIntervalMinutes,
      notes: notes ?? description,
    );

    final newTask = TaskItem(
      id: generateUuid(),
      householdId: householdId,
      title: title,
      description: packedDescription,
      referenceId: referenceId,
      referenceType: referenceType,
      assignedTo: assignedTo,
      status: TaskStatus.pending,
      pointsReward: pointsReward,
      dueDate: dueDate,
      priority: priority,
      isRecurring: isRecurring,
      repeatIntervalMinutes: repeatIntervalMinutes,
      notes: notes ?? description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await syncService.saveTask(newTask);
  }

  /// Add a new furniture item / appliance
  Future<void> addFurniture({
    required String roomId,
    required String name,
    String? category,
    Map<String, dynamic> positionCoordinates = const {},
  }) async {
    final syncService = ref.read(syncServiceProvider);
    final newFurniture = FurnitureItem(
      id: generateUuid(),
      roomId: roomId,
      name: name,
      category: category,
      positionCoordinates: positionCoordinates,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await syncService.saveFurnitureItem(newFurniture);
  }

  /// Delete a furniture item
  Future<void> deleteFurniture(String furnitureId) async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.deleteFurnitureItem(furnitureId);
  }

  /// Toggle task status (e.g. complete task offline / online) and award points
  Future<({int points, String? awardee})?> toggleTaskStatus(String taskId, TaskStatus currentStatus, {String? completedBy}) async {
    final syncService = ref.read(syncServiceProvider);
    final result = await syncService.toggleTaskStatus(taskId, currentStatus, completedBy: completedBy);
    if (result != null && result.points > 0 && result.awardee != null) {
      ref.read(householdMembersProvider.notifier).addPointsToMember(result.awardee!, result.points);
      final currentMember = ref.read(currentUserProvider);
      if (currentMember != null &&
          (currentMember.id == result.awardee || currentMember.name.toLowerCase() == result.awardee!.toLowerCase())) {
        ref.read(currentUserProvider.notifier).addPoints(result.points);
      }
    }
    return result;
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.deleteTask(taskId);
  }

  /// Trigger immediate manual synchronization
  Future<void> triggerSync() async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.syncAll();
  }
}

final supabaseSyncControllerProvider =
    NotifierProvider<SupabaseSyncController, void>(
  SupabaseSyncController.new,
);
