import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/core/services/cleanliness_engine.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/furniture_item.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/room.dart';
import 'package:spatio_cleaning/core/constants/app_strings.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/controllers/household_state_provider.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/task_item.dart';

void main() {
  group('CleanlinessEngine & TaskItem tests', () {
    final testRoom = Room(
      id: 'room-1',
      householdId: 'hh-1',
      name: 'Living Room',
      floor: 1,
      cleanlinessScore: 100,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final testFurniture = FurnitureItem(
      id: 'furn-1',
      roomId: 'room-1',
      name: 'Sofa',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('CleanlinessEngine returns 100% when no tasks are assigned', () {
      final score = CleanlinessEngine.calculateRoomCleanliness(
        room: testRoom,
        allTasks: [],
        allFurniture: [testFurniture],
      );
      expect(score, equals(100));
    });

    test('CleanlinessEngine returns 100% when all tasks are completed', () {
      final task1 = TaskItem(
        id: 'task-1',
        householdId: 'hh-1',
        title: 'Vacuum',
        referenceId: 'room-1',
        referenceType: TaskReferenceType.room,
        status: TaskStatus.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final score = CleanlinessEngine.calculateRoomCleanliness(
        room: testRoom,
        allTasks: [task1],
        allFurniture: [testFurniture],
      );
      expect(score, equals(100));
    });

    test('CleanlinessEngine reduces score for pending tasks with priority', () {
      final now = DateTime.now();
      final taskLow = TaskItem(
        id: 'task-low',
        householdId: 'hh-1',
        title: 'Dust shelf',
        referenceId: 'room-1',
        referenceType: TaskReferenceType.room,
        status: TaskStatus.pending,
        priority: 1,
        dueDate: now.add(const Duration(hours: 5)),
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now,
      );

      final taskUrgent = TaskItem(
        id: 'task-urgent',
        householdId: 'hh-1',
        title: 'Deep clean',
        referenceId: 'room-1',
        referenceType: TaskReferenceType.room,
        status: TaskStatus.pending,
        priority: 5,
        dueDate: now.add(const Duration(hours: 5)),
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now,
      );

      final scoreLow = CleanlinessEngine.calculateRoomCleanliness(
        room: testRoom,
        allTasks: [taskLow],
        allFurniture: [testFurniture],
        referenceTime: now,
      );

      final scoreUrgent = CleanlinessEngine.calculateRoomCleanliness(
        room: testRoom,
        allTasks: [taskUrgent],
        allFurniture: [testFurniture],
        referenceTime: now,
      );

      // Higher priority task should deduct more from cleanliness score
      expect(scoreLow, greaterThan(scoreUrgent));
    });

    test('CleanlinessEngine penalizes overdue tasks heavily (negative countdown)', () {
      final now = DateTime.now();
      final overdueTask = TaskItem(
        id: 'task-overdue',
        householdId: 'hh-1',
        title: 'Overdue cleanup',
        referenceId: 'room-1',
        referenceType: TaskReferenceType.room,
        status: TaskStatus.pending,
        priority: 4,
        dueDate: now.subtract(const Duration(hours: 12)), // 12 hours overdue!
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      );

      final onTimeTask = TaskItem(
        id: 'task-ontime',
        householdId: 'hh-1',
        title: 'On time cleanup',
        referenceId: 'room-1',
        referenceType: TaskReferenceType.room,
        status: TaskStatus.pending,
        priority: 4,
        dueDate: now.add(const Duration(hours: 12)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      );

      final scoreOverdue = CleanlinessEngine.calculateRoomCleanliness(
        room: testRoom,
        allTasks: [overdueTask],
        allFurniture: [testFurniture],
        referenceTime: now,
      );

      final scoreOnTime = CleanlinessEngine.calculateRoomCleanliness(
        room: testRoom,
        allTasks: [onTimeTask],
        allFurniture: [testFurniture],
        referenceTime: now,
      );

      expect(scoreOverdue, lessThan(scoreOnTime));
    });

    test('CleanlinessEngine includes tasks assigned to furniture inside room', () {
      final now = DateTime.now();
      final furnitureTask = TaskItem(
        id: 'task-furn',
        householdId: 'hh-1',
        title: 'Clean Sofa',
        referenceId: 'furn-1', // belongs to testFurniture in testRoom
        referenceType: TaskReferenceType.furnitureItem,
        status: TaskStatus.pending,
        priority: 3,
        dueDate: now.add(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      );

      final score = CleanlinessEngine.calculateRoomCleanliness(
        room: testRoom,
        allTasks: [furnitureTask],
        allFurniture: [testFurniture],
        referenceTime: now,
      );

      expect(score, lessThan(100));
    });

    test('TaskItem countdown formats correctly for future and overdue deadlines', () {
      final now = DateTime(2026, 9, 27, 12, 0, 0);

      // Future deadline: 2 hours and 30 minutes away
      final futureTask = TaskItem(
        id: 't-future',
        householdId: 'hh-1',
        title: 'Future',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: DateTime(2026, 9, 27, 14, 30, 0),
        createdAt: now,
        updatedAt: now,
      );

      expect(futureTask.isOverdue(now), isFalse);
      expect(futureTask.formattedCountdown(now), equals('02:30:00'));

      // Overdue deadline: 1 hour and 15 minutes in the past
      final overdueTask = TaskItem(
        id: 't-overdue',
        householdId: 'hh-1',
        title: 'Overdue',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: DateTime(2026, 9, 27, 10, 45, 0),
        createdAt: now,
        updatedAt: now,
      );

      expect(overdueTask.isOverdue(now), isTrue);
      expect(overdueTask.formattedCountdown(now), startsWith('-'));
      expect(overdueTask.formattedCountdown(now), equals('-01:15:00'));
    });

    test('TaskItem metadata packing and unpacking preserves priority and recurrence', () {
      final packedDesc = TaskItem.packDescription(
        priority: 4,
        isRecurring: true,
        repeatIntervalMinutes: 2880,
        notes: 'Special care instructions',
      );

      final task = TaskItem(
        id: 't-meta',
        householdId: 'hh-1',
        title: 'Recurring task',
        description: packedDesc,
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.priority, equals(4));
      expect(task.isRecurring, isTrue);
      expect(task.repeatIntervalMinutes, equals(2880));
      expect(task.notes, equals('Special care instructions'));
    });

    test('TaskItem metadata preserves completionHistory across packing and unpacking', () {
      final history = [
        {'who': 'Sarah (Parent)', 'when': '2026-09-27T00:30:00.000Z'},
        {'who': 'Leo (Child)', 'when': '2026-09-26T18:15:00.000Z'},
      ];

      final packed = TaskItem.packDescription(
        priority: 3,
        isRecurring: true,
        repeatIntervalMinutes: 1440,
        completionHistory: history,
      );

      final task = TaskItem(
        id: 't-hist',
        householdId: 'hh-1',
        title: 'Vacuum living room',
        description: packed,
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.completionHistory.length, equals(2));
      expect(task.completionHistory[0]['who'], equals('Sarah (Parent)'));
      expect(task.completionHistory[1]['who'], equals('Leo (Child)'));
    });

    test('AppStrings.floorLabel returns human-friendly floor names', () {
      expect(AppStrings.floorLabel(1), equals('Ground Floor'));
      expect(AppStrings.floorLabel(2), equals('1st Floor'));
      expect(AppStrings.floorLabel(3), equals('2nd Floor'));
      expect(AppStrings.floorLabel(4), equals('3rd Floor'));
      expect(AppStrings.floorLabel(5), equals('4th Floor'));
    });

    test('FamilyMember role predicates distinguish parent and child accounts', () {
      const parent = FamilyMember(
        id: 'p-1',
        name: 'Sarah',
        role: 'parent',
        points: 120,
        avatar: '👩‍💼',
        email: 'sarah@example.com',
      );
      const child = FamilyMember(
        id: 'c-1',
        name: 'Leo',
        role: 'child',
        points: 45,
        avatar: '👦',
        email: 'leo@example.com',
      );

      expect(parent.isParent, isTrue);
      expect(parent.isChild, isFalse);
      expect(child.isParent, isFalse);
      expect(child.isChild, isTrue);
    });
  });
}
