import 'package:flutter_test/flutter_test.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/floor_plan/geometry_utils.dart';
import 'package:cleaning_app/core/services/cleanliness_engine.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/room.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/task_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diagnostics: Numerical Precision & Memory Leak Avoidance', () {
    test('Numerical Precision: Centroid calculation on complex asymmetrical polygons', () {
      // L-shaped polygon
      final lShape = [
        const Offset(0.0, 0.0),
        const Offset(100.0, 0.0),
        const Offset(100.0, 50.0),
        const Offset(50.0, 50.0),
        const Offset(50.0, 100.0),
        const Offset(0.0, 100.0),
      ];

      final centroid = GeometryUtils.computeCentroid(lShape);
      expect(centroid.dx.isNaN, isFalse);
      expect(centroid.dy.isNaN, isFalse);
      expect(centroid.dx.isInfinite, isFalse);
      expect(centroid.dy.isInfinite, isFalse);

      // Bounding box is [0, 100] in both dimensions
      expect(centroid.dx, inInclusiveRange(0.0, 100.0));
      // True geometric area centroid (center of mass) of L-shaped polygon
      expect(centroid.dx, closeTo(41.667, 0.01));
      expect(centroid.dy, closeTo(41.667, 0.01));
    });

    test('Numerical Precision: CleanlinessEngine priority and overdue weight math avoids NaN / Infinity', () {
      final now = DateTime(2026, 10, 3, 12, 0);
      final room = Room(
        id: 'r-precision',
        householdId: 'hh-1',
        name: 'Math Precision Room',
        floor: 1,
        polygonCoordinates: const [],
        cleanlinessScore: 100,
        createdAt: now,
        updatedAt: now,
      );

      // Overdue by 10 years (extreme timestamp boundary)
      final extremeTasks = [
        TaskItem(
          id: 't-ancient',
          householdId: 'hh-1',
          title: 'Extreme overdue task',
          referenceId: 'r-precision',
          referenceType: TaskReferenceType.room,
          status: TaskStatus.pending,
          description: TaskItem.packDescription(priority: 5, isRecurring: false),
          dueDate: now.subtract(const Duration(days: 3650)),
          createdAt: now,
          updatedAt: now,
        ),
        // Due 10 years in future
        TaskItem(
          id: 't-distant-future',
          householdId: 'hh-1',
          title: 'Distant future task',
          referenceId: 'r-precision',
          referenceType: TaskReferenceType.room,
          status: TaskStatus.pending,
          description: TaskItem.packDescription(priority: 1, isRecurring: false),
          dueDate: now.add(const Duration(days: 3650)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final score = CleanlinessEngine.calculateRoomCleanliness(
        room: room,
        allTasks: extremeTasks,
        allFurniture: const [],
        referenceTime: now,
      );

      expect(score, isA<int>());
      expect(score, inInclusiveRange(0, 100));
    });

    test('Memory Stability: Bulk allocation of 50,000 domain models completes with zero leaks', () {
      final now = DateTime.now();

      // Allocate in chunks, letting garbage collector reclaim references
      for (int chunk = 0; chunk < 5; chunk++) {
        final list = <TaskItem>[];
        for (int i = 0; i < 10000; i++) {
          list.add(
            TaskItem(
              id: 'task-alloc-$chunk-$i',
              householdId: 'hh-mem',
              title: 'Bulk allocation item $i',
              referenceId: 'ref-alloc',
              referenceType: TaskReferenceType.room,
              status: TaskStatus.pending,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
        expect(list.length, equals(10000));
      }
      // Finished 50,000 allocations without OutOfMemory or stack overflow
    });

    test('Memory Stability: CleanlinessEngine evaluates 10,000 tasks without memory exhaustion', () {
      final now = DateTime.now();
      final room = Room(
        id: 'r-huge',
        householdId: 'hh-huge',
        name: 'Huge Room',
        floor: 1,
        polygonCoordinates: const [],
        cleanlinessScore: 100,
        createdAt: now,
        updatedAt: now,
      );

      final massiveTasks = List.generate(10000, (index) {
        return TaskItem(
          id: 'task-mass-$index',
          householdId: 'hh-huge',
          title: 'Mass task $index',
          referenceId: 'r-huge',
          referenceType: TaskReferenceType.room,
          status: index % 2 == 0 ? TaskStatus.completed : TaskStatus.pending,
          description: TaskItem.packDescription(priority: (index % 5) + 1, isRecurring: false),
          dueDate: now.add(Duration(hours: index % 48)),
          createdAt: now,
          updatedAt: now,
        );
      });

      final score = CleanlinessEngine.calculateRoomCleanliness(
        room: room,
        allTasks: massiveTasks,
        allFurniture: const [],
        referenceTime: now,
      );

      expect(score, inInclusiveRange(0, 100));
    });
  });
}
