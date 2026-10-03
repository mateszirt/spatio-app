import 'package:flutter_test/flutter_test.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/task_item.dart';

void main() {
  group('TaskItem Domain Entity Tests', () {
    final now = DateTime(2026, 10, 3, 12, 0, 0);

    test('Default properties and initialization', () {
      final task = TaskItem(
        id: 't-1',
        householdId: 'hh-1',
        title: 'Sweep floor',
        referenceId: 'room-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );

      expect(task.id, equals('t-1'));
      expect(task.householdId, equals('hh-1'));
      expect(task.title, equals('Sweep floor'));
      expect(task.referenceId, equals('room-1'));
      expect(task.referenceType, equals(TaskReferenceType.room));
      expect(task.assignedTo, isNull);
      expect(task.status, equals(TaskStatus.pending));
      expect(task.pointsReward, equals(10));
      expect(task.priority, equals(3));
      expect(task.isRecurring, isFalse);
      expect(task.repeatIntervalMinutes, isNull);
      expect(task.notes, isNull);
      expect(task.completionHistory, isEmpty);
      expect(task.isCompleted, isFalse);
      expect(task.isPendingApproval, isFalse);
    });

    test('Priority clamping between 1 and 5', () {
      final taskLowClamp = TaskItem(
        id: 't-low',
        householdId: 'hh-1',
        title: 'Task Low',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        priority: -10,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskLowClamp.priority, equals(1));

      final taskZeroClamp = TaskItem(
        id: 't-zero',
        householdId: 'hh-1',
        title: 'Task Zero',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        priority: 0,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskZeroClamp.priority, equals(1));

      final taskHighClamp = TaskItem(
        id: 't-high',
        householdId: 'hh-1',
        title: 'Task High',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        priority: 999,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskHighClamp.priority, equals(5));

      for (int p = 1; p <= 5; p++) {
        final taskP = TaskItem(
          id: 't-$p',
          householdId: 'hh-1',
          title: 'Task $p',
          referenceId: 'r-1',
          referenceType: TaskReferenceType.room,
          priority: p,
          createdAt: now,
          updatedAt: now,
        );
        expect(taskP.priority, equals(p));
      }
    });

    test('Task completion and approval predicates', () {
      final pendingTask = TaskItem(
        id: 't-pending',
        householdId: 'hh-1',
        title: 'Pending',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        status: TaskStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      expect(pendingTask.isCompleted, isFalse);
      expect(pendingTask.isPendingApproval, isFalse);

      final inProgressTask = pendingTask.copyWith(status: TaskStatus.inProgress);
      expect(inProgressTask.isCompleted, isFalse);
      expect(inProgressTask.isPendingApproval, isFalse);

      final approvalTask = pendingTask.copyWith(status: TaskStatus.pendingApproval);
      expect(approvalTask.isCompleted, isFalse);
      expect(approvalTask.isPendingApproval, isTrue);

      final completedTask = pendingTask.copyWith(status: TaskStatus.completed);
      expect(completedTask.isCompleted, isTrue);
      expect(completedTask.isPendingApproval, isFalse);

      final verifiedTask = pendingTask.copyWith(status: TaskStatus.verified);
      expect(verifiedTask.isCompleted, isTrue);
      expect(verifiedTask.isPendingApproval, isFalse);
    });

    test('isOverdue and remainingDuration calculations', () {
      final dueDateFuture = now.add(const Duration(hours: 3));
      final taskFuture = TaskItem(
        id: 't-fut',
        householdId: 'hh-1',
        title: 'Future',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: dueDateFuture,
        createdAt: now,
        updatedAt: now,
      );

      expect(taskFuture.isOverdue(now), isFalse);
      expect(taskFuture.remainingDuration(now), equals(const Duration(hours: 3)));

      final dueDatePast = now.subtract(const Duration(minutes: 45));
      final taskPast = TaskItem(
        id: 't-past',
        householdId: 'hh-1',
        title: 'Past',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: dueDatePast,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      );

      expect(taskPast.isOverdue(now), isTrue);
      expect(taskPast.remainingDuration(now), equals(const Duration(minutes: -45)));

      // Completed tasks are never overdue
      final taskCompletedPast = taskPast.copyWith(status: TaskStatus.completed);
      expect(taskCompletedPast.isOverdue(now), isFalse);

      // Tasks without dueDate return null / false
      final taskNoDue = TaskItem(
        id: 't-nodue',
        householdId: 'hh-1',
        title: 'No Due',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskNoDue.isOverdue(now), isFalse);
      expect(taskNoDue.remainingDuration(now), isNull);

      // Exact millisecond boundary (now == dueDate) is not overdue
      expect(taskFuture.isOverdue(dueDateFuture), isFalse);
    });

    test('formattedCountdown formatting edge cases', () {
      final taskNoDue = TaskItem(
        id: 't-0',
        householdId: 'hh-1',
        title: 'No Due',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskNoDue.formattedCountdown(now), equals('–'));

      // Under 1 hour future: 25 mins 14 secs
      final task25m = TaskItem(
        id: 't-25m',
        householdId: 'hh-1',
        title: '25m',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: now.add(const Duration(minutes: 25, seconds: 14)),
        createdAt: now,
        updatedAt: now,
      );
      expect(task25m.formattedCountdown(now), equals('00:25:14'));

      // Over 1 hour future: 3 hours 12 mins 5 secs
      final task3h = TaskItem(
        id: 't-3h',
        householdId: 'hh-1',
        title: '3h',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: now.add(const Duration(hours: 3, minutes: 12, seconds: 5)),
        createdAt: now,
        updatedAt: now,
      );
      expect(task3h.formattedCountdown(now), equals('03:12:05'));

      // Multi-day future: 2 days, 5 hours, 30 minutes
      final task2d = TaskItem(
        id: 't-2d',
        householdId: 'hh-1',
        title: '2d',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: now.add(const Duration(days: 2, hours: 5, minutes: 30, seconds: 10)),
        createdAt: now,
        updatedAt: now,
      );
      expect(task2d.formattedCountdown(now), equals('2d 5h 30m'));

      // Negative overdue under 1 hour: -15 mins 40 secs
      final taskOverdueMin = TaskItem(
        id: 't-ovm',
        householdId: 'hh-1',
        title: 'Overdue min',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: now.subtract(const Duration(minutes: 15, seconds: 40)),
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now,
      );
      expect(taskOverdueMin.formattedCountdown(now), equals('-00:15:40'));

      // Negative overdue multi-day: -4 days, 2 hours, 10 minutes
      final taskOverdueDay = TaskItem(
        id: 't-ovd',
        householdId: 'hh-1',
        title: 'Overdue day',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        dueDate: now.subtract(const Duration(days: 4, hours: 2, minutes: 10)),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      );
      expect(taskOverdueDay.formattedCountdown(now), equals('-4d 2h 10m'));
    });

    test('packDescription and parsing with metadata, plain text, and corrupted JSON', () {
      final packed = TaskItem.packDescription(
        priority: 4,
        isRecurring: true,
        repeatIntervalMinutes: 720,
        notes: 'Handle with special care! 🧼',
        completionHistory: [
          {'who': 'User A', 'when': '2026-10-01T10:00:00.000Z'}
        ],
      );

      final taskPacked = TaskItem(
        id: 't-p',
        householdId: 'hh-1',
        title: 'Packed',
        description: packed,
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );

      expect(taskPacked.priority, equals(4));
      expect(taskPacked.isRecurring, isTrue);
      expect(taskPacked.repeatIntervalMinutes, equals(720));
      expect(taskPacked.notes, equals('Handle with special care! 🧼'));
      expect(taskPacked.completionHistory.length, equals(1));
      expect(taskPacked.completionHistory.first['who'], equals('User A'));

      // Plain text legacy fallback
      final taskPlainText = TaskItem(
        id: 't-txt',
        householdId: 'hh-1',
        title: 'Plain text',
        description: 'Just a plain string without JSON formatting',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskPlainText.notes, equals('Just a plain string without JSON formatting'));
      expect(taskPlainText.priority, equals(3)); // default fallback
      expect(taskPlainText.isRecurring, isFalse);

      // Corrupted / malformed JSON string fallback
      final taskCorrupted = TaskItem(
        id: 't-bad',
        householdId: 'hh-1',
        title: 'Corrupted',
        description: '{"priority": 5, "isRecurring": true, broken json...}',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskCorrupted.notes, contains('broken json'));
      expect(taskCorrupted.priority, equals(3));
      expect(taskCorrupted.isRecurring, isFalse);

      // Empty description returns empty string via fallback
      final taskEmpty = TaskItem(
        id: 't-empty',
        householdId: 'hh-1',
        title: 'Empty',
        description: '',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskEmpty.notes, isEmpty);
      expect(taskEmpty.priority, equals(3));
      expect(taskEmpty.isRecurring, isFalse);

      // Null description returns null notes
      final taskNullDesc = TaskItem(
        id: 't-nulldesc',
        householdId: 'hh-1',
        title: 'Null Desc',
        description: null,
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );
      expect(taskNullDesc.notes, isNull);
    });

    test('copyWith preserves immutability and supports partial & sentinel updates', () {
      final original = TaskItem(
        id: 't-orig',
        householdId: 'hh-1',
        title: 'Original Title',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        assignedTo: 'user-1',
        status: TaskStatus.inProgress,
        pointsReward: 25,
        dueDate: now.add(const Duration(days: 1)),
        completedAt: null,
        priority: 4,
        isRecurring: true,
        repeatIntervalMinutes: 1440,
        notes: 'Important notes',
        createdAt: now,
        updatedAt: now,
      );

      // Clone with no changes
      final clone = original.copyWith();
      expect(clone.id, equals(original.id));
      expect(clone.title, equals(original.title));
      expect(clone.assignedTo, equals(original.assignedTo));
      expect(clone.priority, equals(original.priority));
      expect(clone.isRecurring, equals(original.isRecurring));

      // Clear assignedTo using null
      final unassigned = original.copyWith(assignedTo: null);
      expect(unassigned.assignedTo, isNull);
      expect(original.assignedTo, equals('user-1')); // Original stays unchanged!

      // Update multiple fields
      final updated = original.copyWith(
        title: 'Updated Title',
        pointsReward: 50,
        status: TaskStatus.completed,
        completedAt: now,
        priority: 2,
        isRecurring: false,
      );

      expect(updated.title, equals('Updated Title'));
      expect(updated.pointsReward, equals(50));
      expect(updated.status, equals(TaskStatus.completed));
      expect(updated.completedAt, equals(now));
      expect(updated.priority, equals(2));
      expect(updated.isRecurring, isFalse);
      expect(original.title, equals('Original Title'));
    });

    test('operator == and hashCode based on ID and type', () {
      final task1 = TaskItem(
        id: 't-same',
        householdId: 'hh-1',
        title: 'Title 1',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );

      final task2 = TaskItem(
        id: 't-same',
        householdId: 'hh-2',
        title: 'Different Title',
        referenceId: 'r-2',
        referenceType: TaskReferenceType.furnitureItem,
        createdAt: now,
        updatedAt: now,
      );

      final task3 = TaskItem(
        id: 't-different',
        householdId: 'hh-1',
        title: 'Title 1',
        referenceId: 'r-1',
        referenceType: TaskReferenceType.room,
        createdAt: now,
        updatedAt: now,
      );

      expect(task1, equals(task2));
      expect(task1.hashCode, equals(task2.hashCode));
      expect(task1, isNot(equals(task3)));
      expect(task1 == Object(), isFalse);
    });

    test('TaskReferenceType fromString enum mapping', () {
      expect(TaskReferenceType.fromString('Room'), equals(TaskReferenceType.room));
      expect(TaskReferenceType.fromString('room'), equals(TaskReferenceType.room));
      expect(TaskReferenceType.fromString('Furniture_Item'), equals(TaskReferenceType.furnitureItem));
      expect(TaskReferenceType.fromString('furniture_item'), equals(TaskReferenceType.furnitureItem));
      expect(TaskReferenceType.fromString('FURNITURE_ITEM'), equals(TaskReferenceType.furnitureItem));
      expect(TaskReferenceType.fromString('random_garbage'), equals(TaskReferenceType.room));
    });

    test('TaskStatus fromString enum mapping and case insensitivity', () {
      expect(TaskStatus.fromString('pending_approval'), equals(TaskStatus.pendingApproval));
      expect(TaskStatus.fromString('PENDING_APPROVAL'), equals(TaskStatus.pendingApproval));
      expect(TaskStatus.fromString('in_progress'), equals(TaskStatus.inProgress));
      expect(TaskStatus.fromString('IN_PROGRESS'), equals(TaskStatus.inProgress));
      expect(TaskStatus.fromString('completed'), equals(TaskStatus.completed));
      expect(TaskStatus.fromString('COMPLETED'), equals(TaskStatus.completed));
      expect(TaskStatus.fromString('verified'), equals(TaskStatus.verified));
      expect(TaskStatus.fromString('VERIFIED'), equals(TaskStatus.verified));
      expect(TaskStatus.fromString('pending'), equals(TaskStatus.pending));
      expect(TaskStatus.fromString('unknown_status'), equals(TaskStatus.pending));
    });
  });
}
