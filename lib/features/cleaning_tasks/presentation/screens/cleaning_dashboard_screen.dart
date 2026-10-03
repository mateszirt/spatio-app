import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/cleanliness_engine.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/top_snack_bar.dart';
import '../../domain/models/furniture_item.dart';
import '../../domain/models/room.dart';
import '../../domain/models/task_item.dart';
import '../controllers/household_state_provider.dart';
import '../controllers/supabase_sync_controller.dart';
import '../widgets/add_task_dialog.dart';
import 'floor_plan_screen.dart';
import 'household_screen.dart';
import 'account_screen.dart';
import '../../../../core/widgets/task_celebration_overlay.dart';

class CleaningDashboardScreen extends ConsumerStatefulWidget {
  const CleaningDashboardScreen({super.key});

  @override
  ConsumerState<CleaningDashboardScreen> createState() =>
      _CleaningDashboardScreenState();
}

class _CleaningDashboardScreenState extends ConsumerState<CleaningDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<FloorPlanScreenState> _floorPlanKey = GlobalKey<FloorPlanScreenState>();
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // 4 Main Tabs: Floor Plan, Tasks, Rooms, Household (Account accessible via top-right profile icon)
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 0) {
        _floorPlanKey.currentState?.clearGhost();
      }
      if (mounted) setState(() {});
    });

    // Real-time ticking: updates formattedCountdown every second without any database queries
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_tabController.index == 1 || _tabController.index == 2)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startRoomDrawingFlow() {
    final currentMember = ref.read(currentUserProvider);
    if (currentMember?.isChild == true) {
      showTopSnackBar(
        context,
        AppStrings.permissionDenied,
        isError: true,
      );
      return;
    }
    setState(() {
      _tabController.index = 0;
    });
    _floorPlanKey.currentState?.setMode(FloorPlanMode.draw);
    showTopSnackBar(
      context,
      '📐 Tap on the canvas to draw room corners!',
      backgroundColor: const Color(0xFF00897B),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomsAsync = ref.watch(roomsRealtimeStreamProvider);
    final tasksAsync = ref.watch(tasksRealtimeStreamProvider);
    final furnitureAsync = ref.watch(furnitureRealtimeStreamProvider);
    final isOnline = ref.watch(isOnlineStreamProvider).value ?? true;
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;

    final rooms = roomsAsync.value ?? [];
    final tasks = tasksAsync.value ?? [];
    final furnitureList = furnitureAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.cleaning_services_rounded,
                  color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              AppStrings.appName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Pending Sync Badge
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Tooltip(
                message: '$pendingCount ${AppStrings.pendingSyncTooltip}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_problem, size: 13, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        '$pendingCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Online / Offline Status Badge
          Tooltip(
            message: isOnline ? AppStrings.onlineTooltip : AppStrings.offlineTooltip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOnline ? Colors.green.shade200 : Colors.grey.shade400,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? AppStrings.online : AppStrings.offline,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Account Quick Profile Button (Opens Account Screen directly)
          IconButton(
            key: const ValueKey('profile_avatar_button'),
            tooltip: AppStrings.tabAccount,
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.person,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          tabs: [
            const Tab(
              icon: Icon(Icons.map_rounded),
              text: AppStrings.tabFloorPlan,
            ),
            Tab(
              icon: const Icon(Icons.checklist_rtl_rounded),
              text: '${AppStrings.tabTasks} (${tasks.length})',
            ),
            Tab(
              icon: const Icon(Icons.meeting_room_outlined),
              text: '${AppStrings.tabRooms} (${rooms.length})',
            ),
            const Tab(
              icon: Icon(Icons.family_restroom_rounded),
              text: AppStrings.tabHousehold,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: _tabController.index == 0 ? const NeverScrollableScrollPhysics() : null,
        children: [
          // 1. FLOOR PLAN
          FloorPlanScreen(key: _floorPlanKey, isEmbedded: true),

          // 2. TASKS
          _buildTasksTab(context, tasksAsync, rooms, furnitureList),

          // 3. ROOMS & HIERARCHICAL VIEW
          _buildRoomsTab(context, roomsAsync, tasks, furnitureList),

          // 4. HOUSEHOLD
          const HouseholdScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0 || _tabController.index == 3
          ? null
          : (_tabController.index == 1
              ? FloatingActionButton.extended(
                  onPressed: () => AddTaskDialog.show(
                    context,
                    rooms: rooms,
                    furnitureList: furnitureList,
                  ),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text(AppStrings.newTask),
                )
              : (ref.watch(currentUserProvider)?.isChild == true
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: _startRoomDrawingFlow,
                      icon: const Icon(Icons.edit_road_rounded),
                      label: const Text(AppStrings.drawRoom),
                    ))),
    );
  }

  // ===========================================================================
  // 3. ROOMS TAB (HIERARCHICAL ROOM -> TASKS & FURNITURE -> TASKS)
  // ===========================================================================
  Widget _buildRoomsTab(
    BuildContext context,
    AsyncValue<List<Room>> roomsAsync,
    List<TaskItem> allTasks,
    List<FurnitureItem> allFurniture,
  ) {
    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text('Connection info: $err', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      data: (rooms) {
        if (rooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.door_front_door_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 14),
                const Text(
                  AppStrings.noRoomsTitle,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.noRoomsSubtitle,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _startRoomDrawingFlow,
                  icon: const Icon(Icons.edit_road_rounded),
                  label: const Text(AppStrings.drawRoom),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            final dynamicScore = CleanlinessEngine.calculateRoomCleanliness(
              room: room,
              allTasks: allTasks,
              allFurniture: allFurniture,
            );
            return _buildHierarchicalRoomCard(
              context,
              room,
              dynamicScore,
              allFurniture,
              allTasks,
            );
          },
        );
      },
    );
  }

  Widget _buildHierarchicalRoomCard(
    BuildContext context,
    Room room,
    int score,
    List<FurnitureItem> allFurniture,
    List<TaskItem> allTasks,
  ) {
    final theme = Theme.of(context);
    final members = ref.watch(householdMembersProvider);

    Color scoreColor;
    if (score >= 80) {
      scoreColor = Colors.green;
    } else if (score >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    // Direct room tasks
    final roomTasks = allTasks
        .where((t) => t.referenceType == TaskReferenceType.room && t.referenceId == room.id)
        .toList();

    // Furniture in this room
    final roomFurniture = allFurniture.where((f) => f.roomId == room.id).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.meeting_room_rounded, color: theme.colorScheme.primary),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${AppStrings.floorLabel(room.floor)} • ${room.polygonCoordinates.length} vertices',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100.0,
                backgroundColor: Colors.grey.shade200,
                color: scoreColor,
                minHeight: 6,
              ),
            ),
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0)),

            // Action toolbar: Assign Task to Room & Delete Room
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmDeleteRoom(context, room),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text(AppStrings.deleteRoom, style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.add_task_rounded, size: 14),
                  label: const Text(AppStrings.assignTask, style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final rooms = ref.read(roomsRealtimeStreamProvider).value ?? [];
                    AddTaskDialog.show(
                      context,
                      rooms: rooms,
                      furnitureList: allFurniture,
                      initialReferenceType: TaskReferenceType.room,
                      initialTargetId: room.id,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 1. Direct Room Tasks
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF00897B)),
                      const SizedBox(width: 6),
                      Text(
                        '${AppStrings.roomTasks} (${roomTasks.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (roomTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        AppStrings.noTasksInRoom,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    )
                  else
                    ...roomTasks.map((t) => _buildHierarchicalTaskRow(t, members)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2. Furniture in Room
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.chair_outlined, size: 16, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 6),
                          Text(
                            '${AppStrings.roomFurniture} (${roomFurniture.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (roomFurniture.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        AppStrings.noFurnitureInRoom,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    )
                  else
                    ...roomFurniture.map((f) {
                      final fTasks = allTasks
                          .where((t) =>
                              t.referenceType == TaskReferenceType.furnitureItem &&
                              t.referenceId == f.id)
                          .toList();
                      return _buildHierarchicalFurnitureItem(f, fTasks, members, allFurniture);
                    }),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchicalFurnitureItem(
    FurnitureItem furniture,
    List<TaskItem> furnitureTasks,
    List<FamilyMember> members,
    List<FurnitureItem> allFurniture,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(_furnitureEmoji(furniture.category ?? furniture.name)),
                  const SizedBox(width: 6),
                  Text(
                    furniture.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  final rooms = ref.read(roomsRealtimeStreamProvider).value ?? [];
                  AddTaskDialog.show(
                    context,
                    rooms: rooms,
                    furnitureList: allFurniture,
                    initialReferenceType: TaskReferenceType.furnitureItem,
                    initialTargetId: furniture.id,
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_task_rounded, size: 12, color: Color(0xFF00897B)),
                      SizedBox(width: 3),
                      Text('+ Task', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00897B))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (furnitureTasks.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...furnitureTasks.map((t) => _buildHierarchicalTaskRow(t, members)),
          ],
        ],
      ),
    );
  }

  Widget _buildHierarchicalTaskRow(TaskItem task, List<FamilyMember> members) {
    final currentMember = ref.watch(currentUserProvider);
    final isOverdue = task.isOverdue();
    final assigneeName = resolveAssigneeName(task.assignedTo, members);
    final assigneeAvatar = resolveAssigneeAvatar(task.assignedTo, members);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: task.isCompleted,
              activeColor: const Color(0xFF00897B),
              onChanged: (_) async {
                final wasCompleted = task.isCompleted;
                final result = await ref.read(supabaseSyncControllerProvider.notifier).toggleTaskStatus(
                      task.id,
                      task.status,
                      completedBy: currentMember?.name ?? 'Unknown',
                    );
                if (!mounted) return;
                if (!wasCompleted && result != null && result.points > 0) {
                  TaskCelebrationOverlay.show(
                    context,
                    points: result.points,
                    taskTitle: task.title,
                    currentPoints: (currentMember?.points ?? 0) + result.points,
                  );
                } else if (task.isRecurring) {
                  showTopSnackBar(
                    context,
                    '🎉 ${task.title} completed! Recurrence cycle restarted.',
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey.shade500 : const Color(0xFF0F172A),
              ),
            ),
          ),
          // Assignee pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(assigneeAvatar, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
                Text(
                  assigneeName,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Countdown
          if (task.dueDate != null && !task.isCompleted)
            Text(
              task.formattedCountdown(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isOverdue ? Colors.red : Colors.grey.shade700,
              ),
            ),
        ],
      ),
    );
  }

  String _furnitureEmoji(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('bed')) return '🛏️';
    if (lower.contains('sofa')) return '🛋️';
    if (lower.contains('table')) return '🪑';
    if (lower.contains('sink')) return '🚰';
    if (lower.contains('washing') || lower.contains('mosó')) return '🧺';
    if (lower.contains('stairs') || lower.contains('lépcső')) return '🪜';
    return '📦';
  }

  // ===========================================================================
  // 2. TASKS TAB (WITH PERSON FILTER & COMPREHENSIVE STATUS)
  // ===========================================================================
  Widget _buildTasksTab(
    BuildContext context,
    AsyncValue<List<TaskItem>> tasksAsync,
    List<Room> rooms,
    List<FurnitureItem> furnitureList,
  ) {
    final selectedFilter = ref.watch(selectedTaskPersonFilterProvider);
    final members = ref.watch(householdMembersProvider);
    final currentMember = ref.watch(currentUserProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 14),
                const Text(
                  AppStrings.noTasksTitle,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.noTasksSubtitle,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => AddTaskDialog.show(
                    context,
                    rooms: rooms,
                    furnitureList: furnitureList,
                  ),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text(AppStrings.newTask),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        // Apply person filter
        List<TaskItem> filteredTasks = tasks;
        if (selectedFilter != null) {
          if (selectedFilter == 'unassigned') {
            filteredTasks = tasks.where((t) => t.assignedTo == null || t.assignedTo!.trim().isEmpty).toList();
          } else {
            filteredTasks = tasks.where((t) {
              final resolved = resolveAssigneeName(t.assignedTo, members);
              return resolved.toLowerCase() == selectedFilter.toLowerCase() || t.assignedTo == selectedFilter;
            }).toList();
          }
        }

        final roomMap = {for (final r in rooms) r.id: r.name};
        final furnitureMap = {for (final f in furnitureList) f.id: f.name};

        return Column(
          children: [
            // Filter by Person Horizontal Chip Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF00897B)),
                    const SizedBox(width: 8),
                    const Text(
                      AppStrings.filterByPerson,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(width: 8),
                    // "All" filter chip
                    FilterChip(
                      label: Text('${AppStrings.filterAll} (${tasks.length})'),
                      selected: selectedFilter == null,
                      onSelected: (_) => ref.read(selectedTaskPersonFilterProvider.notifier).setFilter(null),
                      selectedColor: const Color(0xFF00897B).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: selectedFilter == null ? FontWeight.bold : FontWeight.normal,
                        color: selectedFilter == null ? const Color(0xFF004D40) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // "Unassigned" filter chip
                    FilterChip(
                      label: Text('👤 ${AppStrings.unassigned} (${tasks.where((t) => t.assignedTo == null || t.assignedTo!.isEmpty).length})'),
                      selected: selectedFilter == 'unassigned',
                      onSelected: (_) => ref.read(selectedTaskPersonFilterProvider.notifier).setFilter('unassigned'),
                      selectedColor: const Color(0xFF00897B).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: selectedFilter == 'unassigned' ? FontWeight.bold : FontWeight.normal,
                        color: selectedFilter == 'unassigned' ? const Color(0xFF004D40) : const Color(0xFF334155),
                      ),
                    ),
                    // Member filter chips
                    ...members.map((m) {
                      final isSel = selectedFilter == m.name;
                      final count = tasks.where((t) => resolveAssigneeName(t.assignedTo, members) == m.name).length;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: FilterChip(
                          avatar: Text(m.avatar),
                          label: Text('${m.name} ($count)'),
                          selected: isSel,
                          onSelected: (_) => ref.read(selectedTaskPersonFilterProvider.notifier).setFilter(isSel ? null : m.name),
                          selectedColor: const Color(0xFF00897B).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? const Color(0xFF004D40) : const Color(0xFF334155),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Task list/grid
            Expanded(
              child: filteredTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_alt_off_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No tasks found for the selected filter.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => ref.read(selectedTaskPersonFilterProvider.notifier).setFilter(null),
                            child: const Text('Clear Filter'),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final isDesktop = width >= 800;

                        if (!isDesktop) {
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) => _buildTaskCard(
                              context,
                              filteredTasks[index],
                              roomMap,
                              furnitureMap,
                              members,
                              currentMember,
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 155,
                          ),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) => _buildTaskCard(
                            context,
                            filteredTasks[index],
                            roomMap,
                            furnitureMap,
                            members,
                            currentMember,
                            margin: EdgeInsets.zero,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    TaskItem task,
    Map<String, String> roomMap,
    Map<String, String> furnitureMap,
    List<FamilyMember> members,
    FamilyMember? currentMember, {
    EdgeInsetsGeometry? margin,
  }) {
    final isRoom = task.referenceType == TaskReferenceType.room;
    final targetName = isRoom
        ? (roomMap[task.referenceId] ?? 'Room')
        : (furnitureMap[task.referenceId] ?? 'Furniture');
    final isOverdue = task.isOverdue();
    final countdownStr = task.formattedCountdown();
    final assigneeName = resolveAssigneeName(task.assignedTo, members);
    final assigneeAvatar = resolveAssigneeAvatar(task.assignedTo, members);

    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: task.isCompleted
              ? Colors.green.shade200
              : (isOverdue ? Colors.red.shade300 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: ListTile(
          leading: Checkbox(
            value: task.isCompleted,
            activeColor: const Color(0xFF00897B),
            onChanged: (_) async {
              final wasCompleted = task.isCompleted;
              final result = await ref.read(supabaseSyncControllerProvider.notifier).toggleTaskStatus(
                    task.id,
                    task.status,
                    completedBy: currentMember?.name ?? 'Someone',
                  );
              if (!wasCompleted && result != null && result.points > 0 && context.mounted) {
                TaskCelebrationOverlay.show(
                  context,
                  points: result.points,
                  taskTitle: task.title,
                  currentPoints: (currentMember?.points ?? 0) + result.points,
                );
              } else if (task.isRecurring && context.mounted) {
                showTopSnackBar(
                  context,
                  '🎉 ${task.title} completed! Recurrence cycle restarted.',
                );
              }
            },
          ),
          title: Text(
            task.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey.shade500 : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                // Target badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRoom ? Colors.blue.shade50 : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isRoom ? Colors.blue.shade200 : Colors.purple.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRoom ? Icons.meeting_room : Icons.chair,
                        size: 11,
                        color: isRoom ? Colors.blue.shade700 : Colors.purple.shade700,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        targetName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isRoom ? Colors.blue.shade700 : Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Assigned Person Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: task.assignedTo != null ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: task.assignedTo != null ? const Color(0xFFBAE6FD) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(assigneeAvatar, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Text(
                        '${AppStrings.assignedTo}: $assigneeName',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: task.assignedTo != null ? const Color(0xFF0369A1) : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Priority Badge (1 - 5)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: task.priority >= 4
                        ? Colors.red.shade50
                        : (task.priority == 3 ? Colors.amber.shade50 : Colors.teal.shade50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${task.priority}⭐',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: task.priority >= 4
                          ? Colors.red.shade800
                          : (task.priority == 3 ? Colors.amber.shade900 : Colors.teal.shade800),
                    ),
                  ),
                ),

                // Countdown / Overdue Badge (Ticks live every second!)
                if (task.dueDate != null && !task.isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOverdue ? Colors.red.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOverdue ? Colors.red.shade300 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 11,
                          color: isOverdue ? Colors.red.shade900 : Colors.black87,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isOverdue ? '$countdownStr overdue' : countdownStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? Colors.red.shade900 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Recurring Badge & History
                if (task.isRecurring)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat, size: 11, color: Colors.green.shade800),
                        const SizedBox(width: 2),
                        Text(
                          task.completionHistory.isNotEmpty
                              ? 'Repeat • Last: ${task.completionHistory.first['by']}'
                              : 'Repeat',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Points Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${task.pointsReward} ${AppStrings.pointsSuffix}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            onPressed: () {
              ref.read(supabaseSyncControllerProvider.notifier).deleteTask(task.id);
            },
          ),
        ),
      ),
    );
  }

  void _confirmDeleteRoom(BuildContext context, Room room) {
    final currentMember = ref.read(currentUserProvider);
    if (currentMember?.isChild == true) {
      showTopSnackBar(
        context,
        AppStrings.permissionDenied,
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(AppStrings.deleteRoomConfirmTitle),
          ],
        ),
        content: Text(
          AppStrings.deleteRoomConfirmMsg.replaceFirst('%s', room.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(supabaseSyncControllerProvider.notifier).deleteRoom(room.id);
              if (context.mounted) {
                showTopSnackBar(
                  context,
                  AppStrings.roomDeleted,
                  isError: true,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
