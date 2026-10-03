import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/data/models/task_item_dto.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/data/models/room_dto.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/data/models/furniture_item_dto.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/task_item.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/room.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/furniture_item.dart';

void main() {
  group('DTO & Data Mapper Unit Tests', () {
    final now = DateTime.parse('2026-10-03T12:00:00.000Z');

    // ─────────────────────────────────────────────────────────────────────────
    // TASK ITEM DTO
    // ─────────────────────────────────────────────────────────────────────────
    group('TaskItemDto', () {
      test('fromDomain and toDomain exact preservation', () {
        final task = TaskItem(
          id: 't-100',
          householdId: 'hh-1',
          title: 'Wash Dishes',
          description: '{"priority": 4, "isRecurring": true}',
          referenceId: 'furn-sink',
          referenceType: TaskReferenceType.furnitureItem,
          assignedTo: 'user-anna',
          status: TaskStatus.inProgress,
          pointsReward: 15,
          dueDate: now.add(const Duration(hours: 4)),
          completedAt: null,
          createdAt: now,
          updatedAt: now,
        );

        final dto = TaskItemDto.fromDomain(task);
        expect(dto.id, equals('t-100'));
        expect(dto.referenceType, equals('Furniture_Item'));
        expect(dto.status, equals('in_progress'));

        final domain = dto.toDomain();
        expect(domain.id, equals(task.id));
        expect(domain.title, equals(task.title));
        expect(domain.referenceType, equals(TaskReferenceType.furnitureItem));
        expect(domain.status, equals(TaskStatus.inProgress));
        expect(domain.pointsReward, equals(15));
        expect(domain.priority, equals(4));
        expect(domain.isRecurring, isTrue);
      });

      test('fromJson and toJson roundtrip serialization', () {
        final json = {
          'id': 't-json-1',
          'household_id': 'hh-1',
          'title': 'Dust Bookshelf',
          'description': 'Handle glass shelves carefully',
          'reference_id': 'room-1',
          'reference_type': 'Room',
          'assigned_to': 'user-bob',
          'status': 'completed',
          'points_reward': 20,
          'due_date': '2026-10-04T10:00:00.000Z',
          'completed_at': '2026-10-03T18:30:00.000Z',
          'created_at': '2026-10-01T08:00:00.000Z',
          'updated_at': '2026-10-03T18:30:00.000Z',
        };

        final dto = TaskItemDto.fromJson(json);
        expect(dto.id, equals('t-json-1'));
        expect(dto.title, equals('Dust Bookshelf'));
        expect(dto.dueDate, equals(DateTime.parse('2026-10-04T10:00:00.000Z')));
        expect(dto.completedAt, equals(DateTime.parse('2026-10-03T18:30:00.000Z')));

        final serialized = dto.toJson();
        expect(serialized['id'], equals('t-json-1'));
        expect(serialized['points_reward'], equals(20));
        expect(serialized['status'], equals('completed'));
        expect(serialized['due_date'], equals('2026-10-04T10:00:00.000Z'));
      });

      test('fromJson fallback defaults when optional fields are null or missing', () {
        final minimalJson = {
          'id': 't-min',
          'household_id': 'hh-1',
          'title': 'Quick wipe',
          'reference_id': 'r-1',
          'reference_type': 'Room',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final dto = TaskItemDto.fromJson(minimalJson);
        expect(dto.description, isNull);
        expect(dto.assignedTo, isNull);
        expect(dto.status, equals('pending'));
        expect(dto.pointsReward, equals(10));
        expect(dto.dueDate, isNull);
        expect(dto.completedAt, isNull);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ROOM DTO
    // ─────────────────────────────────────────────────────────────────────────
    group('RoomDto', () {
      test('fromDomain and toDomain conversion', () {
        final room = Room(
          id: 'r-50',
          householdId: 'hh-1',
          name: 'Living Room',
          floor: 2,
          polygonCoordinates: [
            {'x': 10.0, 'y': 20.0},
            {'x': 100.0, 'y': 20.0},
            {'x': 100.0, 'y': 150.0},
            {'x': 10.0, 'y': 150.0},
          ],
          cleanlinessScore: 88,
          createdAt: now,
          updatedAt: now,
        );

        final dto = RoomDto.fromDomain(room);
        expect(dto.id, equals('r-50'));
        expect(dto.floor, equals(2));
        expect(dto.cleanlinessScore, equals(88));
        expect(dto.polygonCoordinates.length, equals(4));

        final domain = dto.toDomain();
        expect(domain.id, equals(room.id));
        expect(domain.name, equals(room.name));
        expect(domain.floor, equals(2));
        expect(domain.cleanlinessScore, equals(88));
        expect(domain.polygonCoordinates, equals(room.polygonCoordinates));
      });

      test('fromJson and toJson roundtrip', () {
        final json = {
          'id': 'r-json',
          'household_id': 'hh-1',
          'name': 'Dining Room',
          'floor': 1,
          'polygon_coordinates': [
            {'x': 0, 'y': 0},
            {'x': 50, 'y': 50},
          ],
          'cleanliness_score': 92,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final dto = RoomDto.fromJson(json);
        expect(dto.id, equals('r-json'));
        expect(dto.name, equals('Dining Room'));
        expect(dto.cleanlinessScore, equals(92));

        final serialized = dto.toJson();
        expect(serialized['id'], equals('r-json'));
        expect(serialized['polygon_coordinates'], isA<List>());
      });

      test('fromJson defaults for missing optional fields', () {
        final minimal = {
          'id': 'r-min',
          'household_id': 'hh-1',
          'name': 'Bathroom',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final dto = RoomDto.fromJson(minimal);
        expect(dto.floor, equals(1));
        expect(dto.cleanlinessScore, equals(100));
        expect(dto.polygonCoordinates, isEmpty);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // FURNITURE ITEM DTO
    // ─────────────────────────────────────────────────────────────────────────
    group('FurnitureItemDto', () {
      test('fromDomain and toDomain conversion', () {
        final item = FurnitureItem(
          id: 'f-1',
          roomId: 'r-1',
          name: 'Double Bed',
          category: 'bedroom',
          positionCoordinates: {
            'x': 100.0,
            'y': 200.0,
            'width': 140.0,
            'height': 160.0,
            'rotation': 180,
          },
          createdAt: now,
          updatedAt: now,
        );

        final dto = FurnitureItemDto.fromDomain(item);
        expect(dto.name, equals('Double Bed'));
        expect(dto.category, equals('bedroom'));
        expect(dto.positionCoordinates['x'], equals(100.0));

        final domain = dto.toDomain();
        expect(domain.id, equals(item.id));
        expect(domain.name, equals(item.name));
        expect(domain.positionCoordinates, equals(item.positionCoordinates));
      });

      test('fromJson parsing position_coordinates as Map, encoded String, and corrupted string', () {
        // Case 1: position_coordinates as a native Dart Map
        final jsonWithMap = {
          'id': 'f-map',
          'room_id': 'r-1',
          'name': 'Sofa',
          'category': 'living_room',
          'position_coordinates': {'x': 50.0, 'y': 60.0},
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final dtoMap = FurnitureItemDto.fromJson(jsonWithMap);
        expect(dtoMap.positionCoordinates['x'], equals(50.0));

        // Case 2: position_coordinates as encoded JSON String (common SQLite/Drift representation)
        final jsonWithString = {
          'id': 'f-str',
          'room_id': 'r-1',
          'name': 'Sofa',
          'category': 'living_room',
          'position_coordinates': jsonEncode({'x': 75.0, 'y': 85.0, 'rotation': 90}),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final dtoString = FurnitureItemDto.fromJson(jsonWithString);
        expect(dtoString.positionCoordinates['x'], equals(75.0));
        expect(dtoString.positionCoordinates['rotation'], equals(90));

        // Case 3: position_coordinates as corrupted invalid JSON string (fault-tolerance test)
        final jsonWithBrokenString = {
          'id': 'f-broken',
          'room_id': 'r-1',
          'name': 'Broken item',
          'category': 'laundry',
          'position_coordinates': '{invalid json broken string...',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final dtoBroken = FurnitureItemDto.fromJson(jsonWithBrokenString);
        expect(dtoBroken.positionCoordinates, isEmpty); // Graceful recovery to empty map!

        // Case 4: position_coordinates as null
        final jsonWithNull = {
          'id': 'f-null',
          'room_id': 'r-1',
          'name': 'Null coords',
          'position_coordinates': null,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final dtoNull = FurnitureItemDto.fromJson(jsonWithNull);
        expect(dtoNull.positionCoordinates, isEmpty);
      });
    });
  });
}
