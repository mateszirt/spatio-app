import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/user_remote_data_source.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/models/task_item.dart';
import '../../domain/models/user_effort_snapshot.dart';
import '../../domain/repositories/i_user_repository.dart';
import '../../domain/usecases/assign_task_usecase.dart';
import 'supabase_sync_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final userRemoteDataSourceProvider = Provider<IUserRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return UserRemoteDataSource(client);
});

final userRepositoryProvider = Provider<IUserRepository>((ref) {
  return UserRepositoryImpl(ref.watch(userRemoteDataSourceProvider));
});

/// Egy háztartás összes tagjának 14 napos effort-snapshot-ja.
/// [householdId] paraméteres family provider – szükség esetén .family()-vel hívható.
final effortSnapshotsProvider = FutureProvider.family<List<UserEffortSnapshot>, String>(
  (ref, householdId) async {
    final repo = ref.watch(userRepositoryProvider);
    final since = DateTime.now().subtract(const Duration(days: 14));

    final users = await repo.getUsersByHousehold(householdId);

    // Párhuzamos effort-pont lekérés minden taghoz
    final snapshots = await Future.wait(
      users.map((user) async {
        final points = await repo.getEffortPoints(user.id, since: since);
        return UserEffortSnapshot.fromUser(user, effortPoints: points);
      }),
    );
    return snapshots;
  },
);

/// Csak a pending_approval státuszú feladatok stream-je.
/// A FloorPlanScreen ezt figyeli az animált érme overlay-hez.
final pendingApprovalTasksProvider = Provider<List<TaskItem>>((ref) {
  final tasks = ref.watch(tasksRealtimeStreamProvider).value ?? [];
  return tasks.where((t) => t.isPendingApproval).toList();
});

final taskAssignmentControllerProvider =
    AsyncNotifierProvider<TaskAssignmentController, TaskAssignmentResult?>(
  TaskAssignmentController.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

/// A legutóbbi kiosztás eredménye – UI visszajelzéshez
class TaskAssignmentResult {
  final TaskItem assignedTask;
  final TaskAssignmentBranch branch;
  final String assigneeName;

  const TaskAssignmentResult({
    required this.assignedTask,
    required this.branch,
    required this.assigneeName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────────────────────────────────────

class TaskAssignmentController extends AsyncNotifier<TaskAssignmentResult?> {
  @override
  Future<TaskAssignmentResult?> build() async => null;

  // ────────────── ÁG 1: FELNŐTT LOAD-BALANCING ────────────────────────────

  /// Automatikusan a legkevésbé terhelt felnőttnek osztja ki a feladatot.
  ///
  /// Lépések:
  /// 1. Lekéri az összes tag 14 napos effort-snapshot-ját
  /// 2. [AssignTaskUseCase.selectLeastBusyAdult] kiválasztja a minimumot
  /// 3. Elmenti a feladatot a Drift lokális DB-be (majd Supabase-be szinkronizálja)
  Future<void> assignToLeastBusyAdult({
    required TaskItem task,
    required String householdId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 1. Effort snapshot-ok lekérése
      final snapshots = await ref.read(
        effortSnapshotsProvider(householdId).future,
      );

      // 2. Load-balancing pure function
      final leastBusy = AssignTaskUseCase.selectLeastBusyAdult(snapshots);
      if (leastBusy == null) {
        throw StateError(
          'Nincs elérhető felnőtt felhasználó a háztartásban: $householdId',
        );
      }

      // 3. Domain-szintű átalakítás
      final assignedTask = AssignTaskUseCase.applyAdultAssignment(
        task,
        leastBusy.userId,
      );

      // 4. Mentés (Drift → Supabase szinkron)
      await ref.read(taskItemRepositoryProvider).saveTask(assignedTask);

      // 5. Snapshots invalidálása (frissült az effort-adat)
      ref.invalidate(effortSnapshotsProvider(householdId));

      return TaskAssignmentResult(
        assignedTask: assignedTask,
        branch: TaskAssignmentBranch.adultLoadBalance,
        assigneeName: leastBusy.name,
      );
    });
  }

  // ────────────── ÁG 2: GYERMEK JÓVÁHAGYÁSI RENDSZER ─────────────────────

  /// A feladatot `pending_approval` státuszba helyezi és a gyermekhez rendeli.
  /// Az animált érme overlay automatikusan megjelenik a FloorPlanScreen-en.
  Future<void> assignToChildForApproval({
    required TaskItem task,
    required String childId,
    required String childName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 1. Domain-szintű átalakítás (pure fn)
      final pendingTask = AssignTaskUseCase.markAsPendingApproval(task, childId);

      // 2. Mentés → FloorPlanScreen automatikusan frissül (pendingApprovalTasksProvider)
      await ref.read(taskItemRepositoryProvider).saveTask(pendingTask);

      return TaskAssignmentResult(
        assignedTask: pendingTask,
        branch: TaskAssignmentBranch.childApproval,
        assigneeName: childName,
      );
    });
  }

  // ────────────── ADMIN JÓVÁHAGYÁS / ELUTASÍTÁS ────────────────────────────

  /// Admin jóváhagyja a gyermek feladatát: pending_approval → in_progress
  Future<void> approveChildTask(TaskItem task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final approved = AssignTaskUseCase.approveChildTask(task);
      await ref.read(taskItemRepositoryProvider).saveTask(approved);
      return TaskAssignmentResult(
        assignedTask: approved,
        branch: TaskAssignmentBranch.adultLoadBalance,
        assigneeName: '',
      );
    });
  }

  /// Admin visszaküldi a feladatot: pending_approval → pending (kiosztás nélkül)
  Future<void> rejectChildTask(TaskItem task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final rejected = AssignTaskUseCase.rejectChildTask(task);
      await ref.read(taskItemRepositoryProvider).saveTask(rejected);
      return TaskAssignmentResult(
        assignedTask: rejected,
        branch: TaskAssignmentBranch.childApproval,
        assigneeName: '',
      );
    });
  }
}
