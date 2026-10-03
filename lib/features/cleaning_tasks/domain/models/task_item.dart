import 'dart:convert';

enum TaskReferenceType {
  room('Room'),
  furnitureItem('Furniture_Item');

  final String value;
  const TaskReferenceType(this.value);

  static TaskReferenceType fromString(String val) {
    if (val == 'Furniture_Item' || val.toLowerCase() == 'furniture_item') {
      return TaskReferenceType.furnitureItem;
    }
    return TaskReferenceType.room;
  }
}

enum TaskStatus {
  pending('pending'),
  pendingApproval('pending_approval'), // Waiting for parent approval
  inProgress('in_progress'),
  completed('completed'),
  verified('verified');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'pending_approval':
        return TaskStatus.pendingApproval;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'verified':
        return TaskStatus.verified;
      default:
        return TaskStatus.pending;
    }
  }
}

/// Polymorphic cleaning task entity with priority, deadline, recurrence, and countdown support
class TaskItem {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final String referenceId; // Room ID or Furniture ID
  final TaskReferenceType referenceType; // 'Room' or 'Furniture_Item'
  final String? assignedTo;
  final TaskStatus status;
  final int pointsReward;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Cached decoded metadata from description
  final int _priority;
  final bool _isRecurring;
  final int? _repeatIntervalMinutes;
  final String? _notes;
  final List<Map<String, dynamic>> _completionHistory;

  TaskItem({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    required this.referenceId,
    required this.referenceType,
    this.assignedTo,
    this.status = TaskStatus.pending,
    this.pointsReward = 10,
    this.dueDate,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    int? priority,
    bool? isRecurring,
    int? repeatIntervalMinutes,
    String? notes,
    List<Map<String, dynamic>>? completionHistory,
  })  : _priority = priority ?? _parseMetadata(description)['priority'] as int? ?? 3,
        _isRecurring = isRecurring ?? _parseMetadata(description)['isRecurring'] as bool? ?? false,
        _repeatIntervalMinutes = repeatIntervalMinutes ?? _parseMetadata(description)['repeatIntervalMinutes'] as int?,
        _notes = notes ?? _parseMetadata(description)['notes'] as String?,
        _completionHistory = completionHistory ??
            (_parseMetadata(description)['completionHistory'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [];

  /// Priority scale: 1 (Low) to 5 (Critical/Urgent)
  int get priority => _priority.clamp(1, 5);

  /// Whether this task repeats automatically upon completion
  bool get isRecurring => _isRecurring;

  /// Recurrence interval in minutes
  int? get repeatIntervalMinutes => _repeatIntervalMinutes;

  /// User notes or plain text description
  String? get notes => _notes ?? description;

  /// Recent completions history (who completed it and when)
  List<Map<String, dynamic>> get completionHistory => _completionHistory;

  bool get isCompleted => status == TaskStatus.completed || status == TaskStatus.verified;
  bool get isPendingApproval => status == TaskStatus.pendingApproval;

  /// Checks if task is overdue given a timestamp
  bool isOverdue([DateTime? referenceTime]) {
    if (dueDate == null || isCompleted) return false;
    final now = referenceTime ?? DateTime.now();
    return now.isAfter(dueDate!);
  }

  /// Calculates remaining duration (negative if overdue)
  Duration? remainingDuration([DateTime? referenceTime]) {
    if (dueDate == null) return null;
    final now = referenceTime ?? DateTime.now();
    return dueDate!.difference(now);
  }

  /// Formatted countdown string (e.g. "-02:45:10" or "03h 25m")
  String formattedCountdown([DateTime? referenceTime]) {
    final diff = remainingDuration(referenceTime);
    if (diff == null) return '–';

    final isNegative = diff.isNegative;
    final absDiff = diff.abs();
    final days = absDiff.inDays;
    final hours = absDiff.inHours % 24;
    final minutes = absDiff.inMinutes % 60;
    final seconds = absDiff.inSeconds % 60;

    final prefix = isNegative ? '-' : '';
    if (days > 0) {
      return '$prefix${days}d ${hours}h ${minutes}m';
    }
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$prefix$hStr:$mStr:$sStr';
  }

  /// Helper to pack metadata into description string
  static String packDescription({
    required int priority,
    required bool isRecurring,
    int? repeatIntervalMinutes,
    String? notes,
    List<Map<String, dynamic>>? completionHistory,
  }) {
    final map = <String, dynamic>{
      'priority': priority.clamp(1, 5),
      'isRecurring': isRecurring,
    };
    if (repeatIntervalMinutes != null) {
      map['repeatIntervalMinutes'] = repeatIntervalMinutes;
    }
    if (notes != null && notes.isNotEmpty) {
      map['notes'] = notes;
    }
    if (completionHistory != null && completionHistory.isNotEmpty) {
      map['completionHistory'] = completionHistory;
    }
    return jsonEncode(map);
  }

  static Map<String, dynamic> _parseMetadata(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Plain text description
      return {'notes': raw};
    }
    return {};
  }

  /// Sentinel object for copyWith
  static const Object _sentinel = Object();

  TaskItem copyWith({
    String? id,
    String? householdId,
    String? title,
    Object? description = _sentinel,
    String? referenceId,
    TaskReferenceType? referenceType,
    Object? assignedTo = _sentinel,
    TaskStatus? status,
    int? pointsReward,
    Object? dueDate = _sentinel,
    Object? completedAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? priority,
    bool? isRecurring,
    int? repeatIntervalMinutes,
    String? notes,
    List<Map<String, dynamic>>? completionHistory,
  }) {
    final newPriority = priority ?? _priority;
    final newIsRecurring = isRecurring ?? _isRecurring;
    final newRepeatInterval = repeatIntervalMinutes ?? _repeatIntervalMinutes;
    final newNotes = notes ?? _notes;
    final newCompletionHistory = completionHistory ?? _completionHistory;

    final newDesc = !identical(description, _sentinel)
        ? description as String?
        : packDescription(
            priority: newPriority,
            isRecurring: newIsRecurring,
            repeatIntervalMinutes: newRepeatInterval,
            notes: newNotes,
            completionHistory: newCompletionHistory,
          );

    return TaskItem(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      description: newDesc,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      assignedTo: identical(assignedTo, _sentinel) ? this.assignedTo : assignedTo as String?,
      status: status ?? this.status,
      pointsReward: pointsReward ?? this.pointsReward,
      dueDate: identical(dueDate, _sentinel) ? this.dueDate : dueDate as DateTime?,
      completedAt: identical(completedAt, _sentinel) ? this.completedAt : completedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: newPriority,
      isRecurring: newIsRecurring,
      repeatIntervalMinutes: newRepeatInterval,
      notes: newNotes,
      completionHistory: newCompletionHistory,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
