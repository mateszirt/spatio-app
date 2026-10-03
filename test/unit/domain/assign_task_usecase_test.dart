import 'package:flutter_test/flutter_test.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/app_user.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/task_item.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/user_effort_snapshot.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/usecases/assign_task_usecase.dart';

void main() {
  group('AssignTaskUseCase Exhaustive & Fault Tolerance Tests', () {
    final now = DateTime(2026, 10, 3, 12, 0, 0);

    final adminA = UserEffortSnapshot(
      userId: 'admin-a',
      name: 'Anna',
      role: UserRole.admin,
      effortPoints: 50,
    );

    final adminB = UserEffortSnapshot(
      userId: 'admin-b',
      name: 'Béla',
      role: UserRole.admin,
      effortPoints: 20,
    );

    final adminC = UserEffortSnapshot(
      userId: 'admin-c',
      name: 'Csaba',
      role: UserRole.admin,
      effortPoints: 35,
    );

    final child = UserEffortSnapshot(
      userId: 'child-1',
      name: 'Kati',
      role: UserRole.child,
      effortPoints: 5,
    );

    final sampleTask = TaskItem(
      id: 'task-001',
      householdId: 'hh-001',
      title: 'Porszívózás',
      referenceId: 'room-001',
      referenceType: TaskReferenceType.room,
      pointsReward: 15,
      createdAt: now,
      updatedAt: now,
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 1. FELNŐTT LOAD-BALANCING
    // ─────────────────────────────────────────────────────────────────────────
    group('selectLeastBusyAdult()', () {
      test('a legkevesebb effortPoints-szal rendelkező felnőttet választja ki', () {
        final result = AssignTaskUseCase.selectLeastBusyAdult([adminA, adminB, adminC]);
        expect(result?.userId, equals('admin-b'));
      });

      test('egyenlő pontszám esetén az első egyező tagot adja vissza', () {
        final equal1 = UserEffortSnapshot(userId: 'x', name: 'X', role: UserRole.admin, effortPoints: 30);
        final equal2 = UserEffortSnapshot(userId: 'y', name: 'Y', role: UserRole.admin, effortPoints: 30);
        final result = AssignTaskUseCase.selectLeastBusyAdult([equal1, equal2]);
        expect(result?.userId, equals('x'));
      });

      test('üres lista esetén null-t ad vissza', () {
        final result = AssignTaskUseCase.selectLeastBusyAdult([]);
        expect(result, isNull);
      });

      test('csak gyermekeket tartalmazó listából null-t ad vissza', () {
        final result = AssignTaskUseCase.selectLeastBusyAdult([child]);
        expect(result, isNull);
      });

      test('vegyes listából csak a felnőtteket veszi figyelembe', () {
        final result = AssignTaskUseCase.selectLeastBusyAdult([adminA, child, adminB]);
        expect(result?.userId, equals('admin-b'));
      });

      test('egyetlen felnőtt esetén azt adja vissza', () {
        final result = AssignTaskUseCase.selectLeastBusyAdult([adminA]);
        expect(result?.userId, equals('admin-a'));
      });

      test('negatív effort pontokat is helyesen és minimális értékként kezeli', () {
        final adultNeg = UserEffortSnapshot(
          userId: 'admin-neg',
          name: 'Dénes',
          role: UserRole.admin,
          effortPoints: -15,
        );
        final adultZero = UserEffortSnapshot(
          userId: 'admin-zero',
          name: 'Elemér',
          role: UserRole.admin,
          effortPoints: 0,
        );
        final result = AssignTaskUseCase.selectLeastBusyAdult([adminA, adultZero, adultNeg]);
        expect(result?.userId, equals('admin-neg'));
      });

      test('tetszőleges méretű vegyes listából kiszűri a gyermekeket', () {
        final members = [
          UserEffortSnapshot(userId: 'c1', name: 'Child 1', role: UserRole.child, effortPoints: -100),
          UserEffortSnapshot(userId: 'c2', name: 'Child 2', role: UserRole.child, effortPoints: 0),
          UserEffortSnapshot(userId: 'a1', name: 'Adult 1', role: UserRole.admin, effortPoints: 40),
          UserEffortSnapshot(userId: 'c3', name: 'Child 3', role: UserRole.child, effortPoints: 5),
          UserEffortSnapshot(userId: 'a2', name: 'Adult 2', role: UserRole.admin, effortPoints: 25),
        ];
        final selected = AssignTaskUseCase.selectLeastBusyAdult(members);
        expect(selected?.userId, equals('a2'));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. ASSIGNMENT & IMMUTABILITY
    // ─────────────────────────────────────────────────────────────────────────
    group('applyAdultAssignment()', () {
      test('beállítja az assignedTo mezőt és in_progress státuszt', () {
        final result = AssignTaskUseCase.applyAdultAssignment(sampleTask, 'admin-b');
        expect(result.assignedTo, equals('admin-b'));
        expect(result.status, equals(TaskStatus.inProgress));
        expect(result.updatedAt.isAfter(now) || result.updatedAt.isAtSameMomentAs(now), isTrue);
      });

      test('az eredeti feladat nem változik (immutable copyWith)', () {
        AssignTaskUseCase.applyAdultAssignment(sampleTask, 'admin-b');
        expect(sampleTask.assignedTo, isNull);
        expect(sampleTask.status, equals(TaskStatus.pending));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. GYERMEK JÓVÁHAGYÁSI RENDSZER
    // ─────────────────────────────────────────────────────────────────────────
    group('markAsPendingApproval()', () {
      test('pending_approval státuszt és gyermek assignedTo-t állít be', () {
        final result = AssignTaskUseCase.markAsPendingApproval(sampleTask, 'child-1');
        expect(result.assignedTo, equals('child-1'));
        expect(result.status, equals(TaskStatus.pendingApproval));
        expect(result.isPendingApproval, isTrue);
        expect(result.isCompleted, isFalse);
      });

      test('az eredeti feladat nem változik (immutable)', () {
        AssignTaskUseCase.markAsPendingApproval(sampleTask, 'child-1');
        expect(sampleTask.status, equals(TaskStatus.pending));
      });
    });

    group('approveChildTask()', () {
      test('pending_approval → in_progress státuszváltás', () {
        final pending = AssignTaskUseCase.markAsPendingApproval(sampleTask, 'child-1');
        final approved = AssignTaskUseCase.approveChildTask(pending);
        expect(approved.status, equals(TaskStatus.inProgress));
        expect(approved.assignedTo, equals('child-1'));
      });

      test('AssertionError-t dob, ha a feladat nem pending_approval státuszú', () {
        final pendingTask = sampleTask.copyWith(status: TaskStatus.pending);
        expect(
          () => AssignTaskUseCase.approveChildTask(pendingTask),
          throwsA(isA<AssertionError>()),
        );

        final inProgressTask = sampleTask.copyWith(status: TaskStatus.inProgress);
        expect(
          () => AssignTaskUseCase.approveChildTask(inProgressTask),
          throwsA(isA<AssertionError>()),
        );

        final completedTask = sampleTask.copyWith(status: TaskStatus.completed);
        expect(
          () => AssignTaskUseCase.approveChildTask(completedTask),
          throwsA(isA<AssertionError>()),
        );

        final verifiedTask = sampleTask.copyWith(status: TaskStatus.verified);
        expect(
          () => AssignTaskUseCase.approveChildTask(verifiedTask),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('rejectChildTask()', () {
      test('pending_approval → pending státuszváltás, assignedTo törlése', () {
        final pending = AssignTaskUseCase.markAsPendingApproval(sampleTask, 'child-1');
        final rejected = AssignTaskUseCase.rejectChildTask(pending);
        expect(rejected.status, equals(TaskStatus.pending));
        expect(rejected.assignedTo, isNull);
      });

      test('AssertionError-t dob, ha a feladat nem pending_approval státuszú', () {
        final pendingTask = sampleTask.copyWith(status: TaskStatus.pending);
        expect(
          () => AssignTaskUseCase.rejectChildTask(pendingTask),
          throwsA(isA<AssertionError>()),
        );

        final inProgressTask = sampleTask.copyWith(status: TaskStatus.inProgress);
        expect(
          () => AssignTaskUseCase.rejectChildTask(inProgressTask),
          throwsA(isA<AssertionError>()),
        );

        final completedTask = sampleTask.copyWith(status: TaskStatus.completed);
        expect(
          () => AssignTaskUseCase.rejectChildTask(completedTask),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 4. ÁG-DÖNTÉS LOGIKA
    // ─────────────────────────────────────────────────────────────────────────
    group('resolveBranch()', () {
      test('csak felnőtt háztartásban adultLoadBalance ágat választ', () {
        final branch = AssignTaskUseCase.resolveBranch(
          assignee: adminA,
          allMembers: [adminA, adminB],
        );
        expect(branch, equals(TaskAssignmentBranch.adultLoadBalance));
      });

      test('gyermek assignee esetén mindig childApproval ágat választ', () {
        final branch = AssignTaskUseCase.resolveBranch(
          assignee: child,
          allMembers: [adminA, child],
        );
        expect(branch, equals(TaskAssignmentBranch.childApproval));
      });

      test('vegyes háztartásban felnőtt assignee esetén adultLoadBalance', () {
        final branch = AssignTaskUseCase.resolveBranch(
          assignee: adminA,
          allMembers: [adminA, child],
        );
        expect(branch, equals(TaskAssignmentBranch.adultLoadBalance));
      });
    });
  });
}
