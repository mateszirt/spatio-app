import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:cleaning_app/core/database/app_database.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/task_item.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/app_user.dart';
import 'package:cleaning_app/features/cleaning_tasks/data/models/room_dto.dart';
import 'package:cleaning_app/features/cleaning_tasks/data/models/task_item_dto.dart';
import 'package:cleaning_app/features/cleaning_tasks/data/models/furniture_item_dto.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/controllers/household_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diagnostics: Negative & Fault-Tolerance Resilience Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Fault Tolerance: Extreme and negative priority values clamp safely', () {
      final taskNegative = TaskItem(
        id: 't-neg',
        householdId: 'hh-1',
        title: 'Neg Priority',
        description: '{"priority": -99}',
        referenceId: 'ref-1',
        referenceType: TaskReferenceType.room,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(taskNegative.priority, equals(1));

      final taskOverflow = TaskItem(
        id: 't-over',
        householdId: 'hh-1',
        title: 'Overflow Priority',
        description: '{"priority": 99999}',
        referenceId: 'ref-1',
        referenceType: TaskReferenceType.room,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(taskOverflow.priority, equals(5));
    });

    test('Fault Tolerance: Corrupted JSON strings across DTO fromJson mappers fallback safely', () {
      // RoomDto with corrupted coordinates
      final roomJsonCorrupted = {
        'id': 'r-corrupt',
        'household_id': 'hh-1',
        'name': 'Corrupted Room',
        'polygon_coordinates': '{"not": [an, array',
        'cleanliness_score': 'invalid_num',
        'created_at': 'not-a-date',
        'updated_at': null,
      };
      final roomDto = RoomDto.fromJson(roomJsonCorrupted);
      expect(roomDto.polygonCoordinates, isEmpty);
      expect(roomDto.cleanlinessScore, equals(100)); // Default fallback
      expect(roomDto.createdAt, isA<DateTime>());

      // TaskItemDto with nulls and unexpected data types
      final taskJsonCorrupted = {
        'id': 't-corrupt',
        'household_id': 'hh-1',
        'title': null,
        'description': null,
        'reference_id': 'ref-1',
        'reference_type': 'UNRECOGNIZED_TYPE_XYZ',
        'status': 'MALFORMED_STATUS_123',
        'points_reward': 'string_not_int',
        'due_date': 'corrupted-timestamp',
      };
      final taskDto = TaskItemDto.fromJson(taskJsonCorrupted);
      expect(taskDto.title, equals(''));
      final taskDomain = taskDto.toDomain();
      expect(taskDomain.referenceType, equals(TaskReferenceType.room)); // Safe domain fallback
      expect(taskDomain.status, equals(TaskStatus.pending)); // Safe domain fallback
      expect(taskDomain.pointsReward, equals(10)); // Default fallback

      // FurnitureItemDto with unparseable coordinates string
      final furnJsonCorrupted = {
        'id': 'f-corrupt',
        'room_id': 'r-1',
        'name': 'Corrupted Couch',
        'category': null,
        'position_coordinates': '<<<broken>>',
      };
      final furnDto = FurnitureItemDto.fromJson(furnJsonCorrupted);
      expect(furnDto.name, equals('Corrupted Couch'));
      expect(furnDto.category, isNull);
      expect(furnDto.positionCoordinates, isEmpty);
    });

    test('Fault Tolerance: Unknown enum strings map safely to default fallback values', () {
      expect(TaskStatus.fromString('unknown_status'), equals(TaskStatus.pending));
      expect(TaskReferenceType.fromString('other'), equals(TaskReferenceType.room));
      expect(UserRole.fromString('nonexistent_role'), equals(UserRole.child));
    });

    test('Fault Tolerance: SQL injection attempts in table queries are safely escaped by Drift', () async {
      const maliciousPayload = "'; DROP TABLE Rooms; SELECT * FROM Rooms WHERE '1'='1";

      await db.into(db.roomsTable).insert(
        RoomsTableCompanion.insert(
          id: maliciousPayload,
          householdId: 'hh-safe',
          name: maliciousPayload,
          floor: const drift.Value(1),
          polygonCoordinates: const drift.Value('[]'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Verify the table still exists and record was stored verbatim without query injection
      final retrieved = await (db.select(db.roomsTable)..where((t) => t.id.equals(maliciousPayload))).getSingleOrNull();
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals(maliciousPayload));

      // Table is intact
      final allRooms = await db.select(db.roomsTable).get();
      expect(allRooms.length, equals(1));
    });

    test('Fault Tolerance: Negative points deduction never produces negative balances', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final membersNotifier = container.read(householdMembersProvider.notifier);
      membersNotifier.setMembers([
        const FamilyMember(id: 'u-1', name: 'Zack', role: 'child', points: 15, avatar: '👦', email: 'zack@test.com'),
      ]);

      // Deduct massive points
      membersNotifier.deductPointsFromMember('u-1', 100000);
      expect(container.read(householdMembersProvider).first.points, equals(0));

      final userNotifier = container.read(currentUserProvider.notifier);
      userNotifier.setUser(
        const FamilyMember(id: 'u-2', name: 'Zack', role: 'child', points: 5, avatar: '👦', email: 'zack@test.com'),
      );
      userNotifier.deductPoints(50);
      expect(container.read(currentUserProvider)?.points, equals(0));
    });
  });
}
