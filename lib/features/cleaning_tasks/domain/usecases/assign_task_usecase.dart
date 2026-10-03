import '../models/task_item.dart';
import '../models/user_effort_snapshot.dart';

/// Feladatkiosztási logika – Clean, tesztelhető pure függvények.
///
/// Két ág:
/// 1. [assignToAdult]  – Load-balancing: a legkevesebb effort-pontú felnőtt kapja a feladatot
/// 2. [assignToChild]  – Jóváhagyási rendszer: 'pending_approval' státusz + érme overlay
class AssignTaskUseCase {
  AssignTaskUseCase._(); // Nem példányosítható – minden metódus statikus

  // ─────────────────────────────────────────────────────────────────────────
  // ÁG 1: FELNŐTT LOAD-BALANCING
  // ─────────────────────────────────────────────────────────────────────────

  /// A legkevesebb effortPoints-szal rendelkező felnőtt felhasználó kiválasztása.
  ///
  /// Paraméterek:
  /// - [snapshots]: Az összes felnőtt felhasználó [UserEffortSnapshot]-ja (előre lekérve)
  ///
  /// Visszatérés:
  /// - [UserEffortSnapshot] a legkevésbé terhelt felnőttnek
  /// - null, ha nincs felnőtt felhasználó
  ///
  /// Példa:
  /// ```dart
  /// final least = AssignTaskUseCase.selectLeastBusyAdult(snapshots);
  /// if (least != null) task = task.copyWith(assignedTo: least.userId);
  /// ```
  static UserEffortSnapshot? selectLeastBusyAdult(
    List<UserEffortSnapshot> snapshots,
  ) {
    final adults = snapshots.where((s) => s.isAdult).toList();
    if (adults.isEmpty) return null;

    // Lineáris keresés: minimális effortPoints megkeresése O(n)-ben
    UserEffortSnapshot leastBusy = adults.first;
    for (final snapshot in adults.skip(1)) {
      if (snapshot.effortPoints < leastBusy.effortPoints) {
        leastBusy = snapshot;
      }
    }
    return leastBusy;
  }

  /// A [task]-ot a [userId] felnőtt felhasználóhoz rendeli és státuszát
  /// [TaskStatus.inProgress]-re állítja.
  static TaskItem applyAdultAssignment(TaskItem task, String userId) {
    return task.copyWith(
      assignedTo: userId,
      status: TaskStatus.inProgress,
      updatedAt: DateTime.now(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ÁG 2: GYERMEK JÓVÁHAGYÁSI RENDSZER
  // ─────────────────────────────────────────────────────────────────────────

  /// A [task]-ot a [childId] gyermekhez rendeli, de [TaskStatus.pendingApproval]
  /// státuszba helyezi – az admin jóváhagyásáig nem aktív.
  ///
  /// Az eredmény [TaskItem.isPendingApproval] == true lesz, ami a FloorPlanScreen-en
  /// animált érme overlay megjelenítését triggereli az érintett szoba felett.
  ///
  /// Példa:
  /// ```dart
  /// final pendingTask = AssignTaskUseCase.markAsPendingApproval(task, childId);
  /// await repository.saveTask(pendingTask);
  /// ```
  static TaskItem markAsPendingApproval(TaskItem task, String childId) {
    return task.copyWith(
      assignedTo: childId,
      status: TaskStatus.pendingApproval,
      updatedAt: DateTime.now(),
    );
  }

  /// Az admin jóváhagyja a gyermek feladatát:
  /// [TaskStatus.pendingApproval] → [TaskStatus.inProgress]
  static TaskItem approveChildTask(TaskItem task) {
    assert(
      task.isPendingApproval,
      'approveChildTask csak pending_approval státuszú feladatra hívható',
    );
    return task.copyWith(
      status: TaskStatus.inProgress,
      updatedAt: DateTime.now(),
    );
  }

  /// Az admin elutasítja / visszaküldi a gyermek feladatát:
  /// [TaskStatus.pendingApproval] → [TaskStatus.pending]
  static TaskItem rejectChildTask(TaskItem task) {
    assert(
      task.isPendingApproval,
      'rejectChildTask csak pending_approval státuszú feladatra hívható',
    );
    return task.copyWith(
      assignedTo: null, // Sentinel által null-ra állítódik (kiosztás törlése)
      status: TaskStatus.pending,
      updatedAt: DateTime.now(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEGÉDFÜGGVÉNY: automatikus ág-választás
  // ─────────────────────────────────────────────────────────────────────────

  /// Háztartási tagok és az aktív felhasználó szerepköre alapján automatikusan
  /// eldönti, melyik kiosztási ágat alkalmazza:
  /// - Ha az összes tag felnőtt → load-balancing
  /// - Ha a kijelölt tag gyermek → pending_approval
  static TaskAssignmentBranch resolveBranch({
    required UserEffortSnapshot assignee,
    required List<UserEffortSnapshot> allMembers,
  }) {
    final hasChildren = allMembers.any((m) => m.isChild);
    if (assignee.isChild) return TaskAssignmentBranch.childApproval;
    if (!hasChildren) return TaskAssignmentBranch.adultLoadBalance;
    // Vegyes háztartás: az assignee felnőtt, de vannak gyerekek is
    return TaskAssignmentBranch.adultLoadBalance;
  }
}

/// Feladatkiosztási ág jelölője – a controller döntéshozatalához
enum TaskAssignmentBranch {
  /// Csak felnőtt háztartás: automatikus load-balancing
  adultLoadBalance,

  /// Gyermek tagnak szól: admin jóváhagyást igényel
  childApproval,
}
