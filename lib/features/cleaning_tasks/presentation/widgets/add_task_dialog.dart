import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/auth_service.dart';
import '../../domain/models/furniture_item.dart';
import '../../domain/models/room.dart';
import '../../domain/models/task_item.dart';
import '../controllers/household_state_provider.dart';
import '../controllers/supabase_sync_controller.dart';
import '../../../../core/services/presence_service.dart';

class AddTaskDialog extends ConsumerStatefulWidget {
  final List<Room> rooms;
  final List<FurnitureItem> furnitureList;
  final TaskReferenceType initialReferenceType;
  final String? initialTargetId;

  const AddTaskDialog({
    super.key,
    required this.rooms,
    required this.furnitureList,
    this.initialReferenceType = TaskReferenceType.room,
    this.initialTargetId,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Room> rooms,
    required List<FurnitureItem> furnitureList,
    TaskReferenceType initialReferenceType = TaskReferenceType.room,
    String? initialTargetId,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AddTaskDialog(
        rooms: rooms,
        furnitureList: furnitureList,
        initialReferenceType: initialReferenceType,
        initialTargetId: initialTargetId,
      ),
    );
  }

  @override
  ConsumerState<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<AddTaskDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late TaskReferenceType _refType;
  // Furniture can only be chosen from the room selected first.
  String? _roomId;
  String? _furnitureId;
  int _priority = 3;
  int _points = 10;
  bool _isRecurring = false;
  String? _assignedTo;

  // Deadline selection in minutes (e.g. 60 = 1h, 1440 = 1 day, 2880 = 2 days, 10080 = 1 week)
  int _deadlineMinutes = 1440; // Default: 1 day

  HouseholdPresenceNotifier? _presenceNotifier;

  @override
  void initState() {
    super.initState();
    try {
      _presenceNotifier = ref.read(householdPresenceProvider.notifier);
    } catch (_) {}
    _refType = widget.initialReferenceType;

    final target = widget.initialTargetId;
    if (_refType == TaskReferenceType.furnitureItem && target != null) {
      _furnitureId = target;
      for (final f in widget.furnitureList) {
        if (f.id == target) _roomId = f.roomId;
      }
    } else if (target != null) {
      _roomId = target;
    }
    if (_roomId == null && widget.rooms.isNotEmpty) {
      _roomId = widget.rooms.first.id;
    }
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      _presenceNotifier?.trackActivity(
            action: 'typing_task',
            detail: 'Typing task "$title"',
            roomId: _roomId,
          );
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _presenceNotifier?.trackActivity(action: 'idle');
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes mins';
    if (minutes == 60) return '1 hour';
    if (minutes < 1440) return '${minutes ~/ 60} hours';
    if (minutes == 1440) return '1 day';
    if (minutes % 1440 == 0) return '${minutes ~/ 1440} days';
    return '${(minutes / 1440).toStringAsFixed(1)} days';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rooms = widget.rooms;
    final allFurniture = widget.furnitureList;

    final effectiveRoomId = rooms.any((r) => r.id == _roomId)
        ? _roomId
        : (rooms.isNotEmpty ? rooms.first.id : null);
    final roomFurniture = allFurniture.where((f) => f.roomId == effectiveRoomId).toList();
    final effectiveFurnitureId = roomFurniture.any((f) => f.id == _furnitureId)
        ? _furnitureId
        : (roomFurniture.isNotEmpty ? roomFurniture.first.id : null);
    final targetId = _refType == TaskReferenceType.room ? effectiveRoomId : effectiveFurnitureId;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_task_rounded, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      AppStrings.newTask,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.taskTitle,
                  hintText: AppStrings.taskTitleHint,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Target Selector: Room vs Furniture
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    AppStrings.targetType,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  ChoiceChip(
                    label: const Text(AppStrings.targetRoom),
                    selected: _refType == TaskReferenceType.room,
                    onSelected: (selected) {
                      if (selected) setState(() => _refType = TaskReferenceType.room);
                    },
                  ),
                  ChoiceChip(
                    label: const Text(AppStrings.targetFurniture),
                    selected: _refType == TaskReferenceType.furnitureItem,
                    onSelected: (selected) {
                      if (selected) setState(() => _refType = TaskReferenceType.furnitureItem);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Room dropdown (always shown: furniture is chosen from within this room)
              DropdownButtonFormField<String>(
                key: ValueKey('room_dd_$effectiveRoomId'),
                isExpanded: true,
                initialValue: effectiveRoomId,
                decoration: const InputDecoration(
                  labelText: AppStrings.assignedRoom,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                items: rooms
                    .map((r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _roomId = val;
                      _furnitureId = null;
                    });
                  }
                },
              ),

              // Furniture dropdown (limited to the selected room's furniture)
              if (_refType == TaskReferenceType.furnitureItem) ...[
                const SizedBox(height: 14),
                if (roomFurniture.isEmpty)
                  Text(
                    'This room has no furniture yet. Place furniture on the floor plan first.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('furn_dd_${effectiveRoomId}_$effectiveFurnitureId'),
                    isExpanded: true,
                    initialValue: effectiveFurnitureId,
                    decoration: const InputDecoration(
                      labelText: AppStrings.assignedFurniture,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.chair_outlined),
                    ),
                    items: roomFurniture
                        .map((f) => DropdownMenuItem(
                              value: f.id,
                              child: Text(f.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _furnitureId = val);
                    },
                  ),
              ],
              const SizedBox(height: 16),

              // Priority Selector (1 - 5 scale)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        AppStrings.priority,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        _priority == 1
                            ? AppStrings.priority1
                            : _priority == 2
                                ? AppStrings.priority2
                                : _priority == 3
                                    ? AppStrings.priority3
                                    : _priority == 4
                                        ? AppStrings.priority4
                                        : AppStrings.priority5,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _priority >= 4
                              ? Colors.red.shade700
                              : (_priority == 3 ? Colors.orange.shade800 : Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (index) {
                      final p = index + 1;
                      final isSelected = _priority == p;
                      return ChoiceChip(
                        label: Text('$p ⭐'),
                        selected: isSelected,
                        selectedColor: p >= 4
                            ? Colors.red.shade100
                            : (p == 3 ? Colors.amber.shade100 : Colors.teal.shade100),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF00897B) : const Color(0xFFCBD5E1),
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _priority = p);
                        },
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Deadline / Countdown selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        AppStrings.deadline,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        _formatDuration(_deadlineMinutes),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00897B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _durationPresetChip('1 hour', 60),
                        _durationPresetChip('4 hours', 240),
                        _durationPresetChip('12 hours', 720),
                        _durationPresetChip('1 day', 1440),
                        _durationPresetChip('2 days', 2880),
                        _durationPresetChip('3 days', 4320),
                        _durationPresetChip('1 week', 10080),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recurrence Switch (One-time vs Recurring)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRecurring ? AppStrings.recurring : AppStrings.oneTime,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _isRecurring
                            ? 'Repeats every ${_formatDuration(_deadlineMinutes)} on completion'
                            : 'Single task (remains done)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isRecurring,
                      activeThumbColor: const Color(0xFF00897B),
                      onChanged: (val) => setState(() => _isRecurring = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Points reward selector
              DropdownButtonFormField<int>(
                initialValue: _points,
                decoration: const InputDecoration(
                  labelText: AppStrings.rewardPoints,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.stars_outlined),
                ),
                items: [5, 10, 20, 30, 50, 100]
                    .map((p) => DropdownMenuItem(value: p, child: Text('$p ${AppStrings.pointsSuffix}')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _points = val);
                },
              ),
              const SizedBox(height: 16),

              // Assign To Person Selector
              DropdownButtonFormField<String?>(
                initialValue: _assignedTo,
                decoration: const InputDecoration(
                  labelText: AppStrings.assignedTo,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ...ref.watch(householdMembersProvider).map(
                        (m) => DropdownMenuItem<String?>(
                          value: m.name,
                          child: Row(
                            children: [
                              Text(m.avatar),
                              const SizedBox(width: 8),
                              Text('${m.name} (${m.role})'),
                            ],
                          ),
                        ),
                      ),
                ],
                onChanged: (val) => setState(() => _assignedTo = val),
              ),
              const SizedBox(height: 24),

              // Create button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text(AppStrings.createTask, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: targetId == null
                    ? null
                    : () async {
                        final title = _titleController.text.trim();
                        if (title.isEmpty) return;
                        final dueDate = DateTime.now().add(Duration(minutes: _deadlineMinutes));
                        final navigator = Navigator.of(context);

                        await ref.read(supabaseSyncControllerProvider.notifier).addTask(
                              householdId: ref.read(authProvider).householdId ?? '',
                              title: title,
                              referenceId: targetId,
                              referenceType: _refType,
                              assignedTo: _assignedTo,
                              pointsReward: _points,
                              priority: _priority,
                              dueDate: dueDate,
                              isRecurring: _isRecurring,
                              repeatIntervalMinutes: _isRecurring ? _deadlineMinutes : null,
                              notes: _notesController.text.trim(),
                            );
                        if (navigator.mounted) navigator.pop();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationPresetChip(String label, int minutes) {
    final isSelected = _deadlineMinutes == minutes;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF00897B).withValues(alpha: 0.15),
        side: BorderSide(
          color: isSelected ? const Color(0xFF00897B) : const Color(0xFFCBD5E1),
        ),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF004D40) : const Color(0xFF334155),
        ),
        onSelected: (selected) {
          if (selected) setState(() => _deadlineMinutes = minutes);
        },
      ),
    );
  }
}
