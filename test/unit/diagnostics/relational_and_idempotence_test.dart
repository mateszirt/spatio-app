import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:cleaning_app/core/database/app_database.dart';
import 'package:cleaning_app/core/services/sync_service.dart';
import 'package:cleaning_app/core/services/connectivity_service.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/task_item.dart';

class _FakeOfflineConnectivity extends ConnectivityService {
  @override
  Future<bool> isConnected() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diagnostics: Cross-Entity Relations & Idempotence Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Relational Integrity: Cascading room deletion removes all attached furniture and room tasks', () async {
      const hhId = 'hh-rel-1';
      const roomId = 'room-master';

      // Insert Room
      await db.into(db.roomsTable).insert(
        RoomsTableCompanion.insert(
          id: roomId,
          householdId: hhId,
          name: 'Master Bedroom',
          floor: const drift.Value(1),
          polygonCoordinates: const drift.Value('[]'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Insert 2 Furniture items in the room
      await db.into(db.furnitureItemsTable).insert(
        FurnitureItemsTableCompanion.insert(
          id: 'furn-bed',
          roomId: roomId,
          name: 'King Bed',
          category: const drift.Value('Bedroom'),
          positionCoordinates: const drift.Value('{}'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await db.into(db.furnitureItemsTable).insert(
        FurnitureItemsTableCompanion.insert(
          id: 'furn-wardrobe',
          roomId: roomId,
          name: 'Wardrobe',
          category: const drift.Value('Storage'),
          positionCoordinates: const drift.Value('{}'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Insert tasks referencing room and furniture
      await db.into(db.tasksTable).insert(
        TasksTableCompanion.insert(
          id: 'task-vacuum-room',
          householdId: hhId,
          title: 'Vacuum master bedroom',
          referenceId: roomId,
          referenceType: TaskReferenceType.room.value,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await db.into(db.tasksTable).insert(
        TasksTableCompanion.insert(
          id: 'task-make-bed',
          householdId: hhId,
          title: 'Make bed',
          referenceId: 'furn-bed',
          referenceType: TaskReferenceType.furnitureItem.value,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Cascade deletion via SyncService
      final syncService = SyncService(
        db: db,
        supabase: null,
        connectivity: _FakeOfflineConnectivity(),
      );

      await syncService.deleteRoom(roomId);

      // Verify room is gone
      final rooms = await db.select(db.roomsTable).get();
      expect(rooms, isEmpty);

      // Verify furniture in room is gone
      final furniture = await db.select(db.furnitureItemsTable).get();
      expect(furniture, isEmpty);

      // Verify ALL tasks in room (both room tasks and furniture tasks) are completely removed!
      final allTasks = await db.select(db.tasksTable).get();
      expect(allTasks, isEmpty);
    });

    test('Multi-Tenancy Isolation: Queries strictly isolate households from cross-tenant leakage', () async {
      final now = DateTime.now();

      // Create two separate households
      await db.into(db.householdsTable).insert(
        HouseholdsTableCompanion.insert(id: 'hh-tenant-a', name: 'Household Alpha', createdAt: now, updatedAt: now),
      );
      await db.into(db.householdsTable).insert(
        HouseholdsTableCompanion.insert(id: 'hh-tenant-b', name: 'Household Beta', createdAt: now, updatedAt: now),
      );

      // Insert tasks for each household
      await db.into(db.tasksTable).insert(
        TasksTableCompanion.insert(
          id: 'task-a',
          householdId: 'hh-tenant-a',
          title: 'Alpha Secret Task',
          referenceId: 'ref-a',
          referenceType: 'Room',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.into(db.tasksTable).insert(
        TasksTableCompanion.insert(
          id: 'task-b',
          householdId: 'hh-tenant-b',
          title: 'Beta Secret Task',
          referenceId: 'ref-b',
          referenceType: 'Room',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Query Alpha household
      final alphaTasks = await (db.select(db.tasksTable)..where((t) => t.householdId.equals('hh-tenant-a'))).get();
      expect(alphaTasks.length, equals(1));
      expect(alphaTasks.first.title, equals('Alpha Secret Task'));

      // Query Beta household
      final betaTasks = await (db.select(db.tasksTable)..where((t) => t.householdId.equals('hh-tenant-b'))).get();
      expect(betaTasks.length, equals(1));
      expect(betaTasks.first.title, equals('Beta Secret Task'));
    });

    test('Idempotence: insertOnConflictUpdate updates in-place without generating duplicates', () async {
      final now = DateTime.now();

      // Insert initial version
      await db.into(db.roomsTable).insertOnConflictUpdate(
        RoomsTableCompanion.insert(
          id: 'r-idempotent',
          householdId: 'hh-1',
          name: 'Original Name',
          floor: const drift.Value(1),
          polygonCoordinates: const drift.Value('[]'),
          cleanlinessScore: const drift.Value(60),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Re-insert 5 times with modified names
      for (int i = 1; i <= 5; i++) {
        await db.into(db.roomsTable).insertOnConflictUpdate(
          RoomsTableCompanion.insert(
            id: 'r-idempotent',
            householdId: 'hh-1',
            name: 'Updated Name $i',
            floor: const drift.Value(1),
            polygonCoordinates: const drift.Value('[]'),
            cleanlinessScore: drift.Value(60 + i),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Verify strictly 1 row exists
      final allRooms = await db.select(db.roomsTable).get();
      expect(allRooms.length, equals(1));
      expect(allRooms.first.name, equals('Updated Name 5'));
      expect(allRooms.first.cleanlinessScore, equals(65));
    });
  });
}
