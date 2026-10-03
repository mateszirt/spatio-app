import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:spatio_cleaning/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 3, 12, 0, 0);

  setUp(() {
    // Isolated In-Memory database for each test run (Zero disk footprint / no garbage left)
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    // Explicit close to dispose in-memory connection and tables
    await db.close();
  });

  group('Drift In-Memory Database Tests (Zero Residue)', () {
    test('HouseholdsTable and UsersTable CRUD and constraint handling', () async {
      // 1. Insert Household
      await db.into(db.householdsTable).insert(
        HouseholdsTableCompanion(
          id: const Value('hh-100'),
          name: const Value('The Simpsons'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final households = await db.select(db.householdsTable).get();
      expect(households.length, equals(1));
      expect(households.first.name, equals('The Simpsons'));

      // 2. Insert User
      await db.into(db.usersTable).insert(
        UsersTableCompanion(
          id: const Value('user-100'),
          householdId: const Value('hh-100'),
          name: const Value('Homer'),
          email: const Value('homer@simpsons.com'),
          role: const Value('admin'),
          avatarUrl: const Value('🍩'),
          pointsTotal: const Value(50),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final users = await db.select(db.usersTable).get();
      expect(users.length, equals(1));
      expect(users.first.name, equals('Homer'));
      expect(users.first.pointsTotal, equals(50));

      // 3. Update points
      await (db.update(db.usersTable)..where((t) => t.id.equals('user-100'))).write(
        const UsersTableCompanion(pointsTotal: Value(80)),
      );

      final updatedUser = await (db.select(db.usersTable)..where((t) => t.id.equals('user-100'))).getSingle();
      expect(updatedUser.pointsTotal, equals(80));

      // 4. Delete User
      await (db.delete(db.usersTable)..where((t) => t.id.equals('user-100'))).go();
      final remainingUsers = await db.select(db.usersTable).get();
      expect(remainingUsers, isEmpty);
    });

    test('RoomsTable insertOnConflictUpdate and multi-household isolation', () async {
      final room1 = RoomsTableCompanion(
        id: const Value('r-1'),
        householdId: const Value('hh-A'),
        name: const Value('Kitchen A'),
        floor: const Value(1),
        polygonCoordinates: Value(jsonEncode([{'x': 0, 'y': 0}, {'x': 100, 'y': 100}])),
        cleanlinessScore: const Value(90),
        createdAt: Value(now),
        updatedAt: Value(now),
        isPendingSync: const Value(true),
      );

      final room2 = RoomsTableCompanion(
        id: const Value('r-2'),
        householdId: const Value('hh-B'),
        name: const Value('Kitchen B'),
        floor: const Value(1),
        polygonCoordinates: const Value('[]'),
        cleanlinessScore: const Value(100),
        createdAt: Value(now),
        updatedAt: Value(now),
        isPendingSync: const Value(false),
      );

      await db.into(db.roomsTable).insert(room1);
      await db.into(db.roomsTable).insert(room2);

      // Verify multi-tenancy filter
      final hhARooms = await (db.select(db.roomsTable)..where((t) => t.householdId.equals('hh-A'))).get();
      expect(hhARooms.length, equals(1));
      expect(hhARooms.first.name, equals('Kitchen A'));

      final hhBRooms = await (db.select(db.roomsTable)..where((t) => t.householdId.equals('hh-B'))).get();
      expect(hhBRooms.length, equals(1));
      expect(hhBRooms.first.name, equals('Kitchen B'));

      // Conflict update
      await db.into(db.roomsTable).insertOnConflictUpdate(
        RoomsTableCompanion(
          id: const Value('r-1'),
          householdId: const Value('hh-A'),
          name: const Value('Remodeled Kitchen A'),
          floor: const Value(1),
          cleanlinessScore: const Value(95),
          createdAt: Value(now),
          updatedAt: Value(now.add(const Duration(hours: 1))),
          isPendingSync: const Value(false),
        ),
      );

      final updatedRoom = await (db.select(db.roomsTable)..where((t) => t.id.equals('r-1'))).getSingle();
      expect(updatedRoom.name, equals('Remodeled Kitchen A'));
      expect(updatedRoom.cleanlinessScore, equals(95));
      expect(updatedRoom.isPendingSync, isFalse);
    });

    test('FurnitureItemsTable and TasksTable polymorphic relationships', () async {
      // Room
      await db.into(db.roomsTable).insert(
        RoomsTableCompanion(
          id: const Value('r-main'),
          householdId: const Value('hh-1'),
          name: const Value('Living Room'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Furniture in room
      await db.into(db.furnitureItemsTable).insert(
        FurnitureItemsTableCompanion(
          id: const Value('f-sofa'),
          roomId: const Value('r-main'),
          name: const Value('Sofa'),
          category: const Value('living_room'),
          positionCoordinates: Value(jsonEncode({'x': 100, 'y': 100})),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Task 1: Assigned to Room
      await db.into(db.tasksTable).insert(
        TasksTableCompanion(
          id: const Value('t-room'),
          householdId: const Value('hh-1'),
          title: const Value('Vacuum Living Room'),
          referenceId: const Value('r-main'),
          referenceType: const Value('Room'),
          pointsReward: const Value(15),
          status: const Value('pending'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Task 2: Assigned to Furniture
      await db.into(db.tasksTable).insert(
        TasksTableCompanion(
          id: const Value('t-furn'),
          householdId: const Value('hh-1'),
          title: const Value('Wipe Sofa'),
          referenceId: const Value('f-sofa'),
          referenceType: const Value('Furniture_Item'),
          pointsReward: const Value(10),
          status: const Value('in_progress'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final allTasks = await db.select(db.tasksTable).get();
      expect(allTasks.length, equals(2));

      // Query tasks referencing the furniture item
      final furnTasks = await (db.select(db.tasksTable)..where((t) => t.referenceId.equals('f-sofa'))).get();
      expect(furnTasks.length, equals(1));
      expect(furnTasks.first.title, equals('Wipe Sofa'));
    });

    test('SyncQueueTable preserves strict FIFO ordering for offline mutation sync', () async {
      await db.into(db.syncQueueTable).insert(
        SyncQueueTableCompanion(
          targetTable: const Value('Room'),
          recordId: const Value('r-1'),
          operation: const Value('INSERT'),
          payload: const Value('{"name":"Room 1"}'),
          createdAt: Value(now),
        ),
      );

      await db.into(db.syncQueueTable).insert(
        SyncQueueTableCompanion(
          targetTable: const Value('Task'),
          recordId: const Value('t-1'),
          operation: const Value('INSERT'),
          payload: const Value('{"title":"Task 1"}'),
          createdAt: Value(now.add(const Duration(seconds: 1))),
        ),
      );

      await db.into(db.syncQueueTable).insert(
        SyncQueueTableCompanion(
          targetTable: const Value('Task'),
          recordId: const Value('t-1'),
          operation: const Value('UPDATE'),
          payload: const Value('{"status":"completed"}'),
          createdAt: Value(now.add(const Duration(seconds: 2))),
        ),
      );

      final queueEntries = await (db.select(db.syncQueueTable)
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc)]))
          .get();

      expect(queueEntries.length, equals(3));
      expect(queueEntries[0].targetTable, equals('Room'));
      expect(queueEntries[0].operation, equals('INSERT'));
      expect(queueEntries[1].targetTable, equals('Task'));
      expect(queueEntries[1].operation, equals('INSERT'));
      expect(queueEntries[2].targetTable, equals('Task'));
      expect(queueEntries[2].operation, equals('UPDATE'));

      // Process and dequeue first item
      await (db.delete(db.syncQueueTable)..where((t) => t.id.equals(queueEntries[0].id))).go();
      final remainingQueue = await db.select(db.syncQueueTable).get();
      expect(remainingQueue.length, equals(2));
      expect(remainingQueue.first.operation, equals('INSERT'));
    });

    test('All tables cleared cleanly with zero leftover entries', () async {
      // Insert one row into every table
      await db.into(db.householdsTable).insert(
        HouseholdsTableCompanion(id: const Value('h1'), name: const Value('H'), createdAt: Value(now), updatedAt: Value(now)),
      );
      await db.into(db.usersTable).insert(
        UsersTableCompanion(id: const Value('u1'), householdId: const Value('h1'), name: const Value('U'), role: const Value('admin'), createdAt: Value(now), updatedAt: Value(now)),
      );
      await db.into(db.roomsTable).insert(
        RoomsTableCompanion(id: const Value('r1'), householdId: const Value('h1'), name: const Value('R'), createdAt: Value(now), updatedAt: Value(now)),
      );
      await db.into(db.furnitureItemsTable).insert(
        FurnitureItemsTableCompanion(id: const Value('f1'), roomId: const Value('r1'), name: const Value('F'), createdAt: Value(now), updatedAt: Value(now)),
      );
      await db.into(db.tasksTable).insert(
        TasksTableCompanion(id: const Value('t1'), householdId: const Value('h1'), title: const Value('T'), referenceId: const Value('r1'), referenceType: const Value('Room'), createdAt: Value(now), updatedAt: Value(now)),
      );
      await db.into(db.syncQueueTable).insert(
        SyncQueueTableCompanion(targetTable: const Value('T'), recordId: const Value('1'), operation: const Value('INS'), payload: const Value('{}'), createdAt: Value(now)),
      );

      // Execute full purge
      await db.delete(db.syncQueueTable).go();
      await db.delete(db.tasksTable).go();
      await db.delete(db.furnitureItemsTable).go();
      await db.delete(db.roomsTable).go();
      await db.delete(db.usersTable).go();
      await db.delete(db.householdsTable).go();

      expect(await db.select(db.syncQueueTable).get(), isEmpty);
      expect(await db.select(db.tasksTable).get(), isEmpty);
      expect(await db.select(db.furnitureItemsTable).get(), isEmpty);
      expect(await db.select(db.roomsTable).get(), isEmpty);
      expect(await db.select(db.usersTable).get(), isEmpty);
      expect(await db.select(db.householdsTable).get(), isEmpty);
    });
  });
}
