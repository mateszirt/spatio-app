import 'package:flutter_test/flutter_test.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/room.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/furniture_item.dart';

void main() {
  group('Room & FurnitureItem Domain Entity Tests', () {
    final now = DateTime(2026, 10, 3, 12, 0, 0);

    test('Room default values and property access', () {
      final room = Room(
        id: 'r-001',
        householdId: 'hh-1',
        name: 'Master Bedroom',
        createdAt: now,
        updatedAt: now,
      );

      expect(room.id, equals('r-001'));
      expect(room.householdId, equals('hh-1'));
      expect(room.name, equals('Master Bedroom'));
      expect(room.floor, equals(1));
      expect(room.polygonCoordinates, isEmpty);
      expect(room.cleanlinessScore, equals(100));
      expect(room.createdAt, equals(now));
      expect(room.updatedAt, equals(now));
    });

    test('Room copyWith immutability and partial modifications', () {
      final original = Room(
        id: 'r-orig',
        householdId: 'hh-1',
        name: 'Kitchen',
        floor: 1,
        polygonCoordinates: [
          {'x': 0.0, 'y': 0.0},
          {'x': 100.0, 'y': 0.0},
          {'x': 100.0, 'y': 100.0},
          {'x': 0.0, 'y': 100.0},
        ],
        cleanlinessScore: 95,
        createdAt: now,
        updatedAt: now,
      );

      final modified = original.copyWith(
        name: 'Gourmet Kitchen',
        floor: 2,
        cleanlinessScore: 75,
        updatedAt: now.add(const Duration(hours: 1)),
      );

      expect(modified.name, equals('Gourmet Kitchen'));
      expect(modified.floor, equals(2));
      expect(modified.cleanlinessScore, equals(75));
      expect(modified.polygonCoordinates.length, equals(4));
      // Original remains pristine
      expect(original.name, equals('Kitchen'));
      expect(original.floor, equals(1));
      expect(original.cleanlinessScore, equals(95));

      final clone = original.copyWith();
      expect(clone.id, equals(original.id));
      expect(clone.name, equals(original.name));
    });

    test('Room equality and hashCode based on ID', () {
      final roomA = Room(
        id: 'r-100',
        householdId: 'hh-1',
        name: 'Attic',
        createdAt: now,
        updatedAt: now,
      );
      final roomB = Room(
        id: 'r-100',
        householdId: 'hh-2',
        name: 'Different Name',
        createdAt: now,
        updatedAt: now,
      );
      final roomC = Room(
        id: 'r-200',
        householdId: 'hh-1',
        name: 'Attic',
        createdAt: now,
        updatedAt: now,
      );

      expect(roomA, equals(roomB));
      expect(roomA.hashCode, equals(roomB.hashCode));
      expect(roomA, isNot(equals(roomC)));
      expect(roomA == Object(), isFalse);
    });

    test('Room with underground/basement negative floor or high floors', () {
      final basement = Room(
        id: 'r-base',
        householdId: 'hh-1',
        name: 'Wine Cellar',
        floor: -1,
        createdAt: now,
        updatedAt: now,
      );
      expect(basement.floor, equals(-1));

      final penthouse = Room(
        id: 'r-pent',
        householdId: 'hh-1',
        name: 'Sky Lounge',
        floor: 25,
        createdAt: now,
        updatedAt: now,
      );
      expect(penthouse.floor, equals(25));
    });

    test('FurnitureItem default values and properties', () {
      final item = FurnitureItem(
        id: 'furn-01',
        roomId: 'r-001',
        name: 'Armchair',
        createdAt: now,
        updatedAt: now,
      );

      expect(item.id, equals('furn-01'));
      expect(item.roomId, equals('r-001'));
      expect(item.name, equals('Armchair'));
      expect(item.category, isNull);
      expect(item.positionCoordinates, isEmpty);
      expect(item.createdAt, equals(now));
      expect(item.updatedAt, equals(now));
    });

    test('FurnitureItem with detailed placement coordinates and category', () {
      final item = FurnitureItem(
        id: 'furn-02',
        roomId: 'r-001',
        name: 'Queen Bed',
        category: 'bedroom',
        positionCoordinates: {
          'x': 150.5,
          'y': 220.0,
          'width': 120.0,
          'height': 150.0,
          'rotation': 90.0,
        },
        createdAt: now,
        updatedAt: now,
      );

      expect(item.category, equals('bedroom'));
      expect(item.positionCoordinates['x'], equals(150.5));
      expect(item.positionCoordinates['y'], equals(220.0));
      expect(item.positionCoordinates['width'], equals(120.0));
      expect(item.positionCoordinates['height'], equals(150.0));
      expect(item.positionCoordinates['rotation'], equals(90.0));
    });

    test('FurnitureItem equality and hashCode based on ID', () {
      final itemA = FurnitureItem(
        id: 'f-same',
        roomId: 'r-1',
        name: 'Desk',
        createdAt: now,
        updatedAt: now,
      );
      final itemB = FurnitureItem(
        id: 'f-same',
        roomId: 'r-2',
        name: 'Office Chair',
        createdAt: now,
        updatedAt: now,
      );
      final itemC = FurnitureItem(
        id: 'f-diff',
        roomId: 'r-1',
        name: 'Desk',
        createdAt: now,
        updatedAt: now,
      );

      expect(itemA, equals(itemB));
      expect(itemA.hashCode, equals(itemB.hashCode));
      expect(itemA, isNot(equals(itemC)));
      expect(itemA == Object(), isFalse);
    });
  });
}
