import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cleaning_app/core/database/app_database.dart';
import 'package:cleaning_app/core/services/sync_service.dart';
import 'package:cleaning_app/core/services/connectivity_service.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/room.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/furniture_item.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/task_item.dart';

/// Test ConnectivityService simulating offline mode
class OfflineConnectivityService extends ConnectivityService {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<bool> isConnected() async => false;

  @override
  Stream<bool> get onConnectivityChanged =>
      _controller.stream.map((r) => r.any((c) => c != ConnectivityResult.none));

  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late OfflineConnectivityService offlineConnectivity;
  late SyncService syncService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    offlineConnectivity = OfflineConnectivityService();
    syncService = SyncService(
      db: db,
      supabase: null, // Zero Supabase communication -> 100% offline isolation
      connectivity: offlineConnectivity,
    );
  });

  tearDown(() async {
    syncService.dispose();
    offlineConnectivity.dispose();
    await db.close();
  });

  group('SyncService Offline & Cascading Mutation Tests (Zero Residue)', () {
    test('saveRoom saves room locally and writes INSERT mutation to syncQueueTable', () async {
      final room = Room(
        id: 'room-1',
        householdId: 'hh-alpha',
        name: 'Living Room',
        floor: 1,
        polygonCoordinates: const [
          {'x': 0.0, 'y': 0.0},
          {'x': 100.0, 'y': 0.0},
          {'x': 100.0, 'y': 80.0},
          {'x': 0.0, 'y': 80.0},
        ],
        cleanlinessScore: 90,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      await syncService.saveRoom(room);

      // Verify room stored in local database
      final savedRoom = await (db.select(db.roomsTable)..where((t) => t.id.equals('room-1'))).getSingleOrNull();
      expect(savedRoom, isNotNull);
      expect(savedRoom!.name, equals('Living Room'));
      expect(savedRoom.cleanlinessScore, equals(90));
      expect(savedRoom.isPendingSync, isTrue);

      // Verify mutation queued in syncQueueTable
      final queueItems = await db.select(db.syncQueueTable).get();
      expect(queueItems.length, equals(1));
      expect(queueItems.first.targetTable, equals('Room'));
      expect(queueItems.first.recordId, equals('room-1'));
      expect(queueItems.first.operation, equals('INSERT'));
      expect(queueItems.first.payload, contains('Living Room'));
    });

    test('updateRoomCleanliness clamps score between 0 and 100 and queues UPDATE mutation', () async {
      final room = Room(
        id: 'room-2',
        householdId: 'hh-alpha',
        name: 'Kitchen',
        floor: 1,
        polygonCoordinates: const [],
        cleanlinessScore: 50,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveRoom(room);

      // Update with score > 100 (should clamp to 100)
      await syncService.updateRoomCleanliness('room-2', 150);
      var updated = await (db.select(db.roomsTable)..where((t) => t.id.equals('room-2'))).getSingle();
      expect(updated.cleanlinessScore, equals(100));

      // Update with score < 0 (should clamp to 0)
      await syncService.updateRoomCleanliness('room-2', -35);
      updated = await (db.select(db.roomsTable)..where((t) => t.id.equals('room-2'))).getSingle();
      expect(updated.cleanlinessScore, equals(0));

      // Verify UPDATE was queued
      final queue = await db.select(db.syncQueueTable).get();
      final updateMutations = queue.where((q) => q.operation == 'UPDATE').toList();
      expect(updateMutations.length, equals(2));
    });

    test('deleteRoom cascades deletion of attached furniture, attached tasks and queues DELETE', () async {
      final room = Room(
        id: 'room-cascade',
        householdId: 'hh-alpha',
        name: 'Bathroom',
        floor: 1,
        polygonCoordinates: const [],
        cleanlinessScore: 100,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveRoom(room);

      final furniture = FurnitureItem(
        id: 'furn-sink',
        roomId: 'room-cascade',
        name: 'Sink',
        category: 'Plumbing',
        positionCoordinates: const {'x': 10.0, 'y': 20.0},
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveFurnitureItem(furniture);

      final roomTask = TaskItem(
        id: 'task-clean-bath',
        householdId: 'hh-alpha',
        title: 'Mop floor',
        referenceId: 'room-cascade',
        referenceType: TaskReferenceType.room,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveTask(roomTask);

      final furnTask = TaskItem(
        id: 'task-clean-sink',
        householdId: 'hh-alpha',
        title: 'Scrub sink',
        referenceId: 'furn-sink',
        referenceType: TaskReferenceType.furnitureItem,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveTask(furnTask);

      // Perform cascading deleteRoom
      await syncService.deleteRoom('room-cascade');

      // Verify room is deleted
      final roomCheck = await (db.select(db.roomsTable)..where((t) => t.id.equals('room-cascade'))).getSingleOrNull();
      expect(roomCheck, isNull);

      // Verify furniture cascade deleted
      final furnCheck = await (db.select(db.furnitureItemsTable)..where((t) => t.roomId.equals('room-cascade'))).get();
      expect(furnCheck, isEmpty);

      // Verify room task cascade deleted
      final taskCheck = await (db.select(db.tasksTable)..where((t) => t.referenceId.equals('room-cascade'))).get();
      expect(taskCheck, isEmpty);

      // Verify furniture task cascade deleted
      final furnTaskCheck = await (db.select(db.tasksTable)..where((t) => t.referenceId.equals('furn-sink'))).get();
      expect(furnTaskCheck, isEmpty);

      // Verify DELETE queue item
      final queue = await db.select(db.syncQueueTable).get();
      expect(queue.any((q) => q.targetTable == 'Room' && q.operation == 'DELETE' && q.recordId == 'room-cascade'), isTrue);
    });

    test('saveFurnitureItem and deleteFurnitureItem cascades attached tasks and queues operations', () async {
      final furniture = FurnitureItem(
        id: 'furn-desk',
        roomId: 'room-study',
        name: 'Desk',
        category: 'Furniture',
        positionCoordinates: const {'x': 5.0, 'y': 15.0},
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveFurnitureItem(furniture);

      final furnTask = TaskItem(
        id: 'task-wipe-desk',
        householdId: 'hh-alpha',
        title: 'Dust desk',
        referenceId: 'furn-desk',
        referenceType: TaskReferenceType.furnitureItem,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveTask(furnTask);

      // Delete furniture
      await syncService.deleteFurnitureItem('furn-desk');

      final furnCheck = await (db.select(db.furnitureItemsTable)..where((t) => t.id.equals('furn-desk'))).getSingleOrNull();
      expect(furnCheck, isNull);

      final taskCheck = await (db.select(db.tasksTable)..where((t) => t.referenceId.equals('furn-desk'))).get();
      expect(taskCheck, isEmpty);
    });

    test('toggleTaskStatus for one-time task completes task and awards points', () async {
      final task = TaskItem(
        id: 'task-onetime',
        householdId: 'hh-alpha',
        title: 'Take out trash',
        referenceId: 'room-1',
        referenceType: TaskReferenceType.room,
        assignedTo: 'user-kid',
        pointsReward: 25,
        status: TaskStatus.pending,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveTask(task);

      final result = await syncService.toggleTaskStatus('task-onetime', TaskStatus.pending, completedBy: 'user-kid');
      expect(result, isNotNull);
      expect(result!.points, equals(25));
      expect(result.awardee, equals('user-kid'));

      final updatedTask = await (db.select(db.tasksTable)..where((t) => t.id.equals('task-onetime'))).getSingle();
      expect(updatedTask.status, equals(TaskStatus.completed.value));
      expect(updatedTask.completedAt, isNotNull);

      // Toggling completed task back to pending resets completedAt and awards 0 points
      final revertResult = await syncService.toggleTaskStatus('task-onetime', TaskStatus.completed);
      expect(revertResult?.points, equals(0));

      final revertedTask = await (db.select(db.tasksTable)..where((t) => t.id.equals('task-onetime'))).getSingle();
      expect(revertedTask.status, equals(TaskStatus.pending.value));
      expect(revertedTask.completedAt, isNull);
    });

    test('toggleTaskStatus for recurring task calculates next due date, awards points and records history', () async {
      final desc = TaskItem.packDescription(
        priority: 2,
        isRecurring: true,
        repeatIntervalMinutes: 1440, // 1 day
        notes: 'Vacuum thoroughly',
      );
      final task = TaskItem(
        id: 'task-recurring',
        householdId: 'hh-alpha',
        title: 'Vacuum Rug',
        description: desc,
        referenceId: 'room-1',
        referenceType: TaskReferenceType.room,
        assignedTo: 'user-alex',
        pointsReward: 15,
        status: TaskStatus.pending,
        dueDate: DateTime.now().subtract(const Duration(hours: 1)),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveTask(task);

      final result = await syncService.toggleTaskStatus('task-recurring', TaskStatus.pending, completedBy: 'user-alex');
      expect(result, isNotNull);
      expect(result!.points, equals(15));
      expect(result.awardee, equals('user-alex'));

      final updatedRow = await (db.select(db.tasksTable)..where((t) => t.id.equals('task-recurring'))).getSingle();
      // Status remains pending so next cycle is immediately active
      expect(updatedRow.status, equals(TaskStatus.pending.value));
      // Due date was shifted by approximately 24 hours into the future
      expect(updatedRow.dueDate, isNotNull);
      expect(updatedRow.dueDate!.isAfter(DateTime.now()), isTrue);

      // Verify completion history in packed description
      final unpacked = TaskItem(
        id: updatedRow.id,
        householdId: updatedRow.householdId,
        title: updatedRow.title,
        description: updatedRow.description,
        referenceId: updatedRow.referenceId,
        referenceType: TaskReferenceType.fromString(updatedRow.referenceType),
        createdAt: updatedRow.createdAt,
        updatedAt: updatedRow.updatedAt,
      );
      expect(unpacked.completionHistory, isNotEmpty);
      expect(unpacked.completionHistory.first['by'], equals('user-alex'));
    });

    test('watchLocalRooms and watchLocalTasks stream reactive real-time updates', () async {
      final roomStream = syncService.watchLocalRooms(householdId: 'hh-alpha');
      final initialRooms = await roomStream.first;
      expect(initialRooms, isEmpty);

      final taskStream = syncService.watchLocalTasks(householdId: 'hh-alpha');
      final initialTasks = await taskStream.first;
      expect(initialTasks, isEmpty);

      // Trigger stream emission 1
      final room = Room(
        id: 'r-stream',
        householdId: 'hh-alpha',
        name: 'Stream Room',
        floor: 1,
        polygonCoordinates: const [],
        cleanlinessScore: 80,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveRoom(room);

      final updatedRooms = await roomStream.first;
      expect(updatedRooms.length, equals(1));
      expect(updatedRooms.first.name, equals('Stream Room'));

      // Trigger stream emission 2
      final task = TaskItem(
        id: 't-stream',
        householdId: 'hh-alpha',
        title: 'Stream Task',
        referenceId: 'r-stream',
        referenceType: TaskReferenceType.room,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveTask(task);

      final updatedTasks = await taskStream.first;
      expect(updatedTasks.length, equals(1));
      expect(updatedTasks.first.title, equals('Stream Task'));
    });

    test('clearAllLocalData wipes all 6 Drift tables cleanly', () async {
      final room = Room(
        id: 'r-clear',
        householdId: 'hh-clear',
        name: 'Clean Room',
        floor: 1,
        polygonCoordinates: const [],
        cleanlinessScore: 100,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      await syncService.saveRoom(room);

      expect((await db.select(db.roomsTable).get()).length, equals(1));
      expect((await db.select(db.syncQueueTable).get()).length, equals(1));

      await syncService.clearAllLocalData();

      expect((await db.select(db.roomsTable).get()), isEmpty);
      expect((await db.select(db.syncQueueTable).get()), isEmpty);
    });
  });
}
