import 'package:flutter_test/flutter_test.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/floor_plan/geometry_utils.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/floor_plan/furniture_catalog.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/room.dart';

void main() {
  group('GeometryUtils Unit Tests', () {
    test('snapToGrid with default 20px and custom grid sizes', () {
      expect(GeometryUtils.snapToGrid(const Offset(9.0, 11.0)), equals(const Offset(0.0, 20.0)));
      expect(GeometryUtils.snapToGrid(const Offset(10.0, 10.0)), equals(const Offset(20.0, 20.0)));
      expect(GeometryUtils.snapToGrid(const Offset(25.0, 47.0)), equals(const Offset(20.0, 40.0)));
      expect(GeometryUtils.snapToGrid(const Offset(0.0, 0.0)), equals(const Offset(0.0, 0.0)));

      // Custom grid sizes: 10px, 50px, 1px
      expect(
        GeometryUtils.snapToGrid(const Offset(24.0, 26.0), gridSize: 10.0),
        equals(const Offset(20.0, 30.0)),
      );
      expect(
        GeometryUtils.snapToGrid(const Offset(68.0, 122.0), gridSize: 50.0),
        equals(const Offset(50.0, 100.0)),
      );
      expect(
        GeometryUtils.snapToGrid(const Offset(15.4, 28.7), gridSize: 1.0),
        equals(const Offset(15.0, 29.0)),
      );

      // Negative coordinates
      expect(
        GeometryUtils.snapToGrid(const Offset(-12.0, -38.0), gridSize: 20.0),
        equals(const Offset(-20.0, -40.0)),
      );
    });

    test('isPointInPolygon handles degenerate polygons (< 3 points)', () {
      expect(GeometryUtils.isPointInPolygon(const Offset(10, 10), []), isFalse);
      expect(GeometryUtils.isPointInPolygon(const Offset(10, 10), [const Offset(10, 10)]), isFalse);
      expect(
        GeometryUtils.isPointInPolygon(const Offset(10, 10), [const Offset(0, 0), const Offset(20, 20)]),
        isFalse,
      );
    });

    test('isPointInPolygon with triangle and concave L-shaped polygon', () {
      // Triangle (0,0), (100,0), (50,100)
      final triangle = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(50, 100),
      ];

      expect(GeometryUtils.isPointInPolygon(const Offset(50, 30), triangle), isTrue);
      expect(GeometryUtils.isPointInPolygon(const Offset(10, 80), triangle), isFalse);
      expect(GeometryUtils.isPointInPolygon(const Offset(150, 50), triangle), isFalse);

      // Concave L-shaped polygon
      // (0,0) -> (100,0) -> (100,50) -> (50,50) -> (50,100) -> (0,100)
      final lShape = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 50),
        const Offset(50, 50),
        const Offset(50, 100),
        const Offset(0, 100),
      ];

      // Inside horizontal arm
      expect(GeometryUtils.isPointInPolygon(const Offset(80, 25), lShape), isTrue);
      // Inside vertical arm
      expect(GeometryUtils.isPointInPolygon(const Offset(25, 80), lShape), isTrue);
      // In the empty notch corner (outside the polygon!)
      expect(GeometryUtils.isPointInPolygon(const Offset(75, 75), lShape), isFalse);
    });

    test('findRoomAtPoint selects the topmost room when overlapping', () {
      final now = DateTime.now();
      final roomBottom = Room(
        id: 'r-bottom',
        householdId: 'h-1',
        name: 'Lower Room',
        polygonCoordinates: [
          {'x': 0.0, 'y': 0.0},
          {'x': 200.0, 'y': 0.0},
          {'x': 200.0, 'y': 200.0},
          {'x': 0.0, 'y': 200.0},
        ],
        createdAt: now,
        updatedAt: now,
      );

      final roomTop = Room(
        id: 'r-top',
        householdId: 'h-1',
        name: 'Upper Room',
        polygonCoordinates: [
          {'x': 50.0, 'y': 50.0},
          {'x': 150.0, 'y': 50.0},
          {'x': 150.0, 'y': 150.0},
          {'x': 50.0, 'y': 150.0},
        ],
        createdAt: now,
        updatedAt: now,
      );

      final rooms = [roomBottom, roomTop];

      // Point inside both rooms selects the topmost (roomTop, because it is later in the list)
      final hitOverlap = GeometryUtils.findRoomAtPoint(const Offset(100, 100), rooms);
      expect(hitOverlap?.id, equals('r-top'));

      // Point only inside roomBottom
      final hitBottomOnly = GeometryUtils.findRoomAtPoint(const Offset(10, 10), rooms);
      expect(hitBottomOnly?.id, equals('r-bottom'));

      // Point outside all rooms
      final hitOutside = GeometryUtils.findRoomAtPoint(const Offset(300, 300), rooms);
      expect(hitOutside, isNull);
    });

    test('roomToPolygon parses Map format, List format, and malformed entries gracefully', () {
      final now = DateTime.now();
      final roomWithMixedCoords = Room(
        id: 'r-mix',
        householdId: 'h-1',
        name: 'Mixed',
        polygonCoordinates: [
          {'x': 10, 'y': 20}, // num ints
          {'x': 30.5, 'y': 40.5}, // doubles
          [50.0, 60.0], // list format
          'corrupted_entry', // string (ignored)
          {'x': null, 'y': 70.0}, // null x -> 0.0 fallback
        ],
        createdAt: now,
        updatedAt: now,
      );

      final polygon = GeometryUtils.roomToPolygon(roomWithMixedCoords);
      expect(polygon.length, equals(4)); // 3 valid + 1 partial map
      expect(polygon[0], equals(const Offset(10.0, 20.0)));
      expect(polygon[1], equals(const Offset(30.5, 40.5)));
      expect(polygon[2], equals(const Offset(50.0, 60.0)));
      expect(polygon[3], equals(const Offset(0.0, 70.0)));
    });

    test('computeCentroid calculates centroid for empty, single point, pairs, and polygons', () {
      // Empty
      expect(GeometryUtils.computeCentroid([]), equals(Offset.zero));

      // 1 point
      expect(GeometryUtils.computeCentroid([const Offset(25, 30)]), equals(const Offset(25, 30)));

      // 2 points
      expect(
        GeometryUtils.computeCentroid([const Offset(0, 0), const Offset(100, 100)]),
        equals(const Offset(50, 50)),
      );

      // Square: (0,0) -> (100,0) -> (100,100) -> (0,100)
      final square = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];
      final centroidSquare = GeometryUtils.computeCentroid(square);
      expect(centroidSquare.dx, closeTo(50.0, 0.01));
      expect(centroidSquare.dy, closeTo(50.0, 0.01));

      // Collinear degenerate polygon (area ~ 0)
      final collinear = [
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(100, 0),
      ];
      final centroidDegenerate = GeometryUtils.computeCentroid(collinear);
      expect(centroidDegenerate.dx, closeTo(50.0, 0.01));
      expect(centroidDegenerate.dy, closeTo(0.0, 0.01));
    });
  });

  group('FurnitureCatalog Unit Tests', () {
    test('Catalog contains all 11 categories', () {
      expect(FurnitureCatalog.categories.length, equals(11));
      final keys = FurnitureCatalog.categories.map((c) => c.key).toSet();
      expect(
        keys,
        containsAll([
          'living_room',
          'bedroom',
          'kitchen',
          'bathroom',
          'dining',
          'office',
          'kids',
          'laundry',
          'utility',
          'outdoor',
          'stairs',
        ]),
      );
    });

    test('itemsIn returns items filtered by category or all items', () {
      final allItems = FurnitureCatalog.itemsIn('all');
      expect(allItems.length, greaterThan(40));

      final kitchenItems = FurnitureCatalog.itemsIn('kitchen');
      expect(kitchenItems.isNotEmpty, isTrue);
      expect(kitchenItems.every((i) => i.category == 'kitchen'), isTrue);

      final nonExistent = FurnitureCatalog.itemsIn('unknown_category');
      expect(nonExistent, isEmpty);
    });

    test('categoryOf handles legacy mappings and unknown fallbacks', () {
      // Legacy 'appliance' maps to 'laundry'
      expect(FurnitureCatalog.categoryOf('appliance').key, equals('laundry'));

      // Standard category
      expect(FurnitureCatalog.categoryOf('bedroom').key, equals('bedroom'));

      // Fallback for null or unknown category
      expect(FurnitureCatalog.categoryOf(null).key, equals('utility'));
      expect(FurnitureCatalog.categoryOf('non_existent').key, equals('utility'));
    });

    test('byName matches exact names, aliases, and case-insensitively', () {
      // Exact name
      final sofa = FurnitureCatalog.byName('Sofa');
      expect(sofa, isNotNull);
      expect(sofa!.name, equals('Sofa'));

      // Alias 'Kanapé' or 'Couch'
      final sofaKanape = FurnitureCatalog.byName('Kanapé');
      expect(sofaKanape?.name, equals('Sofa'));

      final sofaCouch = FurnitureCatalog.byName('couch');
      expect(sofaCouch?.name, equals('Sofa'));

      // Case insensitive & whitespace trimmed
      final bed = FurnitureCatalog.byName('  dOuBlE bEd  ');
      expect(bed?.name, equals('Double Bed'));

      // Unknown or null
      expect(FurnitureCatalog.byName('Space Rocket'), isNull);
      expect(FurnitureCatalog.byName(null), isNull);
      expect(FurnitureCatalog.byName(''), isNull);
    });

    test('iconFor, emojiFor, colorFor and isStairs resolution', () {
      expect(FurnitureCatalog.emojiFor('Sofa', 'living_room'), equals('🛋️'));
      expect(FurnitureCatalog.emojiFor('Washing Machine', 'laundry'), equals('🧼'));
      expect(FurnitureCatalog.emojiFor('Unknown', 'kids'), equals('🧸')); // category emoji fallback

      expect(FurnitureCatalog.isStairs('Stairs', 'stairs'), isTrue);
      expect(FurnitureCatalog.isStairs('Straight Stairs', null), isTrue); // via alias
      expect(FurnitureCatalog.isStairs('Dining Table', 'dining'), isFalse);

      final colorSofa = FurnitureCatalog.colorFor('Sofa', 'living_room');
      expect(colorSofa, isNotNull);
    });
  });
}
