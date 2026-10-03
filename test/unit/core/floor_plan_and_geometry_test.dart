import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/floor_plan/geometry_utils.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/room.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/furniture_item.dart';

void main() {
  group('FloorPlan & Geometry Tests', () {
    test('GeometryUtils - snapToGrid 20px-es rácshoz illeszt', () {
      expect(GeometryUtils.snapToGrid(const Offset(23.4, 48.9)), const Offset(20.0, 40.0));
      expect(GeometryUtils.snapToGrid(const Offset(31.0, 52.0)), const Offset(40.0, 60.0));
      expect(GeometryUtils.snapToGrid(const Offset(100.0, 200.0)), const Offset(100.0, 200.0));
    });

    test('GeometryUtils - findRoomAtPoint Ray-Casting poligonon belül és kívül', () {
      final sampleRoom = Room(
        id: 'room-1',
        householdId: 'h-1',
        name: 'Nappali',
        floor: 1,
        cleanlinessScore: 90,
        polygonCoordinates: const [
          {'x': 100.0, 'y': 100.0},
          {'x': 300.0, 'y': 100.0},
          {'x': 300.0, 'y': 300.0},
          {'x': 100.0, 'y': 300.0},
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final rooms = [sampleRoom];

      // Belül lévő pont (150, 150)
      final hitInside = GeometryUtils.findRoomAtPoint(const Offset(150, 150), rooms);
      expect(hitInside, isNotNull);
      expect(hitInside!.name, 'Nappali');

      // Kívül lévő pont (50, 50)
      final hitOutside = GeometryUtils.findRoomAtPoint(const Offset(50, 50), rooms);
      expect(hitOutside, isNull);

      // Kívül lévő pont (350, 150)
      final hitOutside2 = GeometryUtils.findRoomAtPoint(const Offset(350, 150), rooms);
      expect(hitOutside2, isNull);
    });

    test('Bútor objektum tárolja az egyedi méreteket és lépcső esetén a célemeletet', () {
      final stairItem = FurnitureItem(
        id: 'stair-1',
        roomId: 'room-1',
        name: 'Lépcső',
        category: 'stairs',
        positionCoordinates: const {
          'x': 200.0,
          'y': 200.0,
          'width': 75.0,
          'height': 110.0,
          'targetFloor': 2,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(stairItem.category, 'stairs');
      expect(stairItem.positionCoordinates['width'], 75.0);
      expect(stairItem.positionCoordinates['height'], 110.0);
      expect(stairItem.positionCoordinates['targetFloor'], 2);
    });

    test('Sims stílusú mosógép bútor testreszabott mérettel rendelkezik', () {
      final washingMachine = FurnitureItem(
        id: 'appliance-1',
        roomId: 'room-1',
        name: 'Mosógép',
        category: 'appliance',
        positionCoordinates: const {
          'x': 150.0,
          'y': 180.0,
          'width': 65.0,
          'height': 65.0,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(washingMachine.category, 'appliance');
      expect(washingMachine.positionCoordinates['width'], 65.0);
      expect(washingMachine.positionCoordinates['height'], 65.0);
    });

    test('AABB ütközésvizsgálat megelőzi a bútorok egymásra helyezését', () {
      bool checkOverlap({
        required Offset posA,
        required double wA,
        required double hA,
        required int rotA,
        required Offset posB,
        required double wB,
        required double hB,
        required int rotB,
      }) {
        final rotA90 = (rotA % 180 != 0);
        final effWA = rotA90 ? hA : wA;
        final effHA = rotA90 ? wA : hA;
        final rectA = Rect.fromCenter(center: posA, width: effWA - 4.0, height: effHA - 4.0);

        final rotB90 = (rotB % 180 != 0);
        final effWB = rotB90 ? hB : wB;
        final effHB = rotB90 ? wB : hB;
        final rectB = Rect.fromCenter(center: posB, width: effWB - 4.0, height: effHB - 4.0);

        return rectA.overlaps(rectB);
      }

      final overlapsSameSpot = checkOverlap(
        posA: const Offset(100, 100),
        wA: 80,
        hA: 60,
        rotA: 0,
        posB: const Offset(120, 110),
        wB: 80,
        hB: 60,
        rotB: 0,
      );
      expect(overlapsSameSpot, isTrue);

      final overlapsDistant = checkOverlap(
        posA: const Offset(100, 100),
        wA: 80,
        hA: 60,
        rotA: 0,
        posB: const Offset(300, 300),
        wB: 80,
        hB: 60,
        rotB: 0,
      );
      expect(overlapsDistant, isFalse);

      final rotatedOverlap = checkOverlap(
        posA: const Offset(100, 100),
        wA: 200,
        hA: 40,
        rotA: 90,
        posB: const Offset(100, 180),
        wB: 50,
        hB: 50,
        rotB: 0,
      );
      expect(rotatedOverlap, isTrue);
    });
  });
}
