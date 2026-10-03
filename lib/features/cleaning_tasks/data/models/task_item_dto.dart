import '../../domain/models/task_item.dart';

class TaskItemDto {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final String referenceId;
  final String referenceType;
  final String? assignedTo;
  final String status;
  final int pointsReward;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskItemDto({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    required this.referenceId,
    required this.referenceType,
    this.assignedTo,
    required this.status,
    required this.pointsReward,
    this.dueDate,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskItemDto.fromDomain(TaskItem task) {
    return TaskItemDto(
      id: task.id,
      householdId: task.householdId,
      title: task.title,
      description: task.description,
      referenceId: task.referenceId,
      referenceType: task.referenceType.value,
      assignedTo: task.assignedTo,
      status: task.status.value,
      pointsReward: task.pointsReward,
      dueDate: task.dueDate,
      completedAt: task.completedAt,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
  }

  TaskItem toDomain() {
    return TaskItem(
      id: id,
      householdId: householdId,
      title: title,
      description: description,
      referenceId: referenceId,
      referenceType: TaskReferenceType.fromString(referenceType),
      assignedTo: assignedTo,
      status: TaskStatus.fromString(status),
      pointsReward: pointsReward,
      dueDate: dueDate,
      completedAt: completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory TaskItemDto.fromJson(Map<String, dynamic> json) {
    return TaskItemDto(
      id: json['id']?.toString() ?? '',
      householdId: json['household_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String? ?? '',
      referenceType: json['reference_type'] as String? ?? 'Room',
      assignedTo: json['assigned_to'] as String?,
      status: json['status'] as String? ?? 'pending',
      pointsReward: (json['points_reward'] is num)
          ? (json['points_reward'] as num).toInt()
          : (int.tryParse(json['points_reward']?.toString() ?? '') ?? 10),
      dueDate: DateTime.tryParse(json['due_date']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'title': title,
      'description': description,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'assigned_to': assignedTo,
      'status': status,
      'points_reward': pointsReward,
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
