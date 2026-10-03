import '../../features/cleaning_tasks/domain/models/furniture_item.dart';
import '../../features/cleaning_tasks/domain/models/room.dart';
import '../../features/cleaning_tasks/domain/models/task_item.dart';

/// Dynamic Room Cleanliness Calculation Engine
///
/// Calculates cleanliness percentage (0-100%) dynamically based on:
/// - Tasks assigned directly to the room
/// - Tasks assigned to furniture items placed within the room
/// - Priority scale (1 to 5)
/// - Remaining deadline ratio and negative overdue duration
class CleanlinessEngine {
  CleanlinessEngine._();

  /// Calculates dynamic cleanliness score (0 - 100) for a given room.
  static int calculateRoomCleanliness({
    required Room room,
    required List<TaskItem> allTasks,
    required List<FurnitureItem> allFurniture,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();

    // 1. Collect all furniture IDs located in this room
    final roomFurnitureIds = allFurniture
        .where((f) => f.roomId == room.id)
        .map((f) => f.id)
        .toSet();

    // 2. Filter tasks belonging to the room or furniture inside the room
    final associatedTasks = allTasks.where((task) {
      if (task.referenceType == TaskReferenceType.room) {
        return task.referenceId == room.id;
      } else if (task.referenceType == TaskReferenceType.furnitureItem) {
        return roomFurnitureIds.contains(task.referenceId);
      }
      return false;
    }).toList();

    // If no tasks exist for this room, it defaults to pristine 100%
    if (associatedTasks.isEmpty) {
      return 100;
    }

    // 3. Compute penalties for incomplete tasks
    double totalPenalty = 0.0;

    for (final task in associatedTasks) {
      // Completed tasks incur 0 penalty
      if (task.isCompleted) continue;

      final priority = task.priority; // 1 to 5
      final baseWeight = priority * 3.5; // 3.5% (Low) to 17.5% (Urgent)

      if (task.dueDate == null) {
        // No deadline specified: standard base penalty
        totalPenalty += baseWeight;
        continue;
      }

      final diff = task.dueDate!.difference(now);

      if (diff.isNegative) {
        // OVERDUE: Escalating penalty multiplier
        final overdueHours = diff.abs().inHours;
        final overdueFactor = (1.8 + (overdueHours * 0.04)).clamp(1.8, 3.5);
        totalPenalty += baseWeight * overdueFactor;
      } else {
        // Within deadline: penalty scales as deadline approaches
        final totalDuration = task.dueDate!.difference(task.createdAt);
        final totalSeconds = totalDuration.inSeconds;
        final remainingSeconds = diff.inSeconds;

        if (totalSeconds > 0) {
          final remainingRatio = (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
          if (remainingRatio > 0.6) {
            totalPenalty += baseWeight * 0.4; // Still plenty of time
          } else if (remainingRatio > 0.2) {
            totalPenalty += baseWeight * 0.8; // Approaching
          } else {
            totalPenalty += baseWeight * 1.2; // Imminent deadline
          }
        } else {
          totalPenalty += baseWeight;
        }
      }
    }

    final calculated = (100.0 - totalPenalty).round();
    return calculated.clamp(0, 100);
  }
}
