import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/core/services/cleanliness_engine.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/room.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/task_item.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/furniture_item.dart';

void main() {
  group('CleanlinessEngine Deep Numerical & Algorithmic Tests', () {
    final now = DateTime(2026, 10, 3, 12, 0, 0);

    final roomA = Room(
      id: 'room-a',
      householdId: 'hh-1',
      name: 'Kitchen',
      cleanlinessScore: 100,
      createdAt: now,
      updatedAt: now,
    );

    final roomB = Room(
      id: 'room-b',
      householdId: 'hh-1',
      name: 'Bathroom',
      cleanlinessScore: 100,
      createdAt: now,
      updatedAt: now,
    );

    final furnA = FurnitureItem(
      id: 'furn-a',
      roomId: 'room-a',
      name: 'Stove',
      createdAt: now,
      updatedAt: now,
    );

    final furnB = FurnitureItem(
      id: 'furn-b',
      roomId: 'room-b',
      name: 'Sink',
      createdAt: now,
      updatedAt: now,
    );

    test('Clean room without tasks defaults to 100%', () {
      final score = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: [],
        allFurniture: [furnA, furnB],
        referenceTime: now,
      );
      expect(score, equals(100));
    });

    test('Room where all tasks are completed or verified retains 100%', () {
      final tasks = [
        TaskItem(
          id: 't-comp1',
          householdId: 'hh-1',
          title: 'Wipe counters',
          referenceId: 'room-a',
          referenceType: TaskReferenceType.room,
          status: TaskStatus.completed,
          createdAt: now,
          updatedAt: now,
        ),
        TaskItem(
          id: 't-comp2',
          householdId: 'hh-1',
          title: 'Clean stove',
          referenceId: 'furn-a',
          referenceType: TaskReferenceType.furnitureItem,
          status: TaskStatus.verified,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final score = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: tasks,
        allFurniture: [furnA],
        referenceTime: now,
      );
      expect(score, equals(100));
    });

    test('Exact base penalty calculation for priority levels 1 to 5 without deadline', () {
      for (int p = 1; p <= 5; p++) {
        final task = TaskItem(
          id: 't-p$p',
          householdId: 'hh-1',
          title: 'Task P$p',
          referenceId: 'room-a',
          referenceType: TaskReferenceType.room,
          priority: p,
          dueDate: null, // No deadline
          createdAt: now,
          updatedAt: now,
        );

        final score = CleanlinessEngine.calculateRoomCleanliness(
          room: roomA,
          allTasks: [task],
          allFurniture: [],
          referenceTime: now,
        );

        final expectedPenalty = p * 3.5;
        final expectedScore = (100.0 - expectedPenalty).round().clamp(0, 100);
        expect(score, equals(expectedScore), reason: 'Priority $p failed');
      }
    });

    test('Deadline ratio progression: generous time (>0.6), approaching (0.2-0.6), imminent (<0.2)', () {
      final created = now.subtract(const Duration(hours: 10)); // Total duration: 10 + X hours

      // Case 1: 80% remaining (> 0.6) -> factor 0.4
      final taskGenerous = TaskItem(
        id: 't-gen',
        householdId: 'hh-1',
        title: 'Generous',
        referenceId: 'room-a',
        referenceType: TaskReferenceType.room,
        priority: 4, // baseWeight = 14.0
        createdAt: created,
        dueDate: now.add(const Duration(hours: 40)), // remaining: 40h out of 50h = 0.8
        updatedAt: now,
      );

      final scoreGenerous = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: [taskGenerous],
        allFurniture: [],
        referenceTime: now,
      );
      // baseWeight * 0.4 = 14.0 * 0.4 = 5.6 -> 100 - 5.6 = 94.4 -> 94
      expect(scoreGenerous, equals(94));

      // Case 2: 50% remaining (0.2 - 0.6) -> factor 0.8
      final taskApproaching = TaskItem(
        id: 't-app',
        householdId: 'hh-1',
        title: 'Approaching',
        referenceId: 'room-a',
        referenceType: TaskReferenceType.room,
        priority: 4, // baseWeight = 14.0
        createdAt: created,
        dueDate: now.add(const Duration(hours: 10)), // remaining: 10h out of 20h = 0.5
        updatedAt: now,
      );

      final scoreApproaching = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: [taskApproaching],
        allFurniture: [],
        referenceTime: now,
      );
      // baseWeight * 0.8 = 14.0 * 0.8 = 11.2 -> 100 - 11.2 = 88.8 -> 89
      expect(scoreApproaching, equals(89));

      // Case 3: 10% remaining (<= 0.2) -> factor 1.2
      final taskImminent = TaskItem(
        id: 't-imm',
        householdId: 'hh-1',
        title: 'Imminent',
        referenceId: 'room-a',
        referenceType: TaskReferenceType.room,
        priority: 4, // baseWeight = 14.0
        createdAt: created,
        dueDate: now.add(const Duration(hours: 1)), // remaining: 1h out of 11h = 0.09
        updatedAt: now,
      );

      final scoreImminent = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: [taskImminent],
        allFurniture: [],
        referenceTime: now,
      );
      // baseWeight * 1.2 = 14.0 * 1.2 = 16.8 -> 100 - 16.8 = 83.2 -> 83
      expect(scoreImminent, equals(83));
    });

    test('Overdue tasks escalating factor with mathematical clamping', () {
      final basePriority = 3; // baseWeight = 10.5

      // Overdue by 0 hours: factor 1.8 -> penalty = 10.5 * 1.8 = 18.9 -> 100 - 18.9 = 81.1 -> 81
      final taskOverdue0h = TaskItem(
        id: 't-ov0',
        householdId: 'hh-1',
        title: 'Overdue 0h',
        referenceId: 'room-a',
        referenceType: TaskReferenceType.room,
        priority: basePriority,
        dueDate: now.subtract(const Duration(minutes: 5)),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );
      final score0h = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: [taskOverdue0h],
        allFurniture: [],
        referenceTime: now,
      );
      expect(score0h, equals(81));

      // Overdue by 10 hours: factor 1.8 + (10 * 0.04) = 2.2 -> penalty = 10.5 * 2.2 = 23.1 -> 76.9 -> 77
      final taskOverdue10h = TaskItem(
        id: 't-ov10',
        householdId: 'hh-1',
        title: 'Overdue 10h',
        referenceId: 'room-a',
        referenceType: TaskReferenceType.room,
        priority: basePriority,
        dueDate: now.subtract(const Duration(hours: 10)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      );
      final score10h = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: [taskOverdue10h],
        allFurniture: [],
        referenceTime: now,
      );
      expect(score10h, equals(77));

      // Overdue by 100 hours: factor clamped to 3.5 -> penalty = 10.5 * 3.5 = 36.75 -> 63.25 -> 63
      final taskOverdue100h = TaskItem(
        id: 't-ov100',
        householdId: 'hh-1',
        title: 'Overdue 100h',
        referenceId: 'room-a',
        referenceType: TaskReferenceType.room,
        priority: basePriority,
        dueDate: now.subtract(const Duration(hours: 100)),
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now,
      );
      final score100h = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: [taskOverdue100h],
        allFurniture: [],
        referenceTime: now,
      );
      expect(score100h, equals(63));
    });

    test('Cleanliness score never drops below 0 even with severe overdue tasks', () {
      final manySevereTasks = List.generate(
        20,
        (i) => TaskItem(
          id: 't-sev-$i',
          householdId: 'hh-1',
          title: 'Severe Task $i',
          referenceId: 'room-a',
          referenceType: TaskReferenceType.room,
          priority: 5,
          dueDate: now.subtract(const Duration(days: 10)),
          createdAt: now.subtract(const Duration(days: 20)),
          updatedAt: now,
        ),
      );

      final score = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: manySevereTasks,
        allFurniture: [],
        referenceTime: now,
      );
      expect(score, equals(0)); // Strictly clamped to 0
    });

    test('Furniture isolation: tasks for furniture in Room B do not affect Room A', () {
      final taskInRoomB = TaskItem(
        id: 't-furn-b',
        householdId: 'hh-1',
        title: 'Scrub bathroom sink',
        referenceId: 'furn-b', // belongs to room-b
        referenceType: TaskReferenceType.furnitureItem,
        priority: 5,
        dueDate: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      );

      final scoreRoomA = CleanlinessEngine.calculateRoomCleanliness(
        room: roomA,
        allTasks: [taskInRoomB],
        allFurniture: [furnA, furnB],
        referenceTime: now,
      );

      final scoreRoomB = CleanlinessEngine.calculateRoomCleanliness(
        room: roomB,
        allTasks: [taskInRoomB],
        allFurniture: [furnA, furnB],
        referenceTime: now,
      );

      expect(scoreRoomA, equals(100)); // Pristine!
      expect(scoreRoomB, lessThan(60)); // Heavily penalized
    });
  });
}
