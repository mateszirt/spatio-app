import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import '../network/supabase_client.dart';
import 'connectivity_service.dart';
import '../../features/cleaning_tasks/domain/models/room.dart';
import '../../features/cleaning_tasks/domain/models/task_item.dart';
import '../../features/cleaning_tasks/domain/models/furniture_item.dart';
import '../../features/cleaning_tasks/data/models/room_dto.dart';
import '../../features/cleaning_tasks/data/models/task_item_dto.dart';
import '../../features/cleaning_tasks/data/models/furniture_item_dto.dart';

/// 2-Way Offline-First Synchronization Service (SyncService)
class SyncService {
  final AppDatabase db;
  final SupabaseClient? supabase;
  final ConnectivityService connectivity;
  StreamSubscription<bool>? _connectivitySub;
  RealtimeChannel? _realtimeChannel;
  String? _subscribedHouseholdId;
  void Function(String householdId)? onUserChanged;
  bool _isSyncing = false;

  SyncService({
    required this.db,
    required this.supabase,
    required this.connectivity,
  }) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySub = connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        // Trigger immediate synchronization as soon as device goes online
        if (_subscribedHouseholdId != null) {
          syncAll(householdId: _subscribedHouseholdId);
        } else {
          syncAll();
        }
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    unsubscribeRealtime();
  }

  // ===========================================================================
  // 0. SUPABASE REALTIME SUBSCRIPTION FOR MULTI-USER INSTANT SYNC
  // ===========================================================================
  void subscribeToHouseholdRealtime(String householdId) {
    if (_subscribedHouseholdId == householdId && _realtimeChannel != null) {
      return;
    }
    unsubscribeRealtime();
    final client = supabase;
    if (client == null) return;

    _subscribedHouseholdId = householdId;
    final channel = client.channel('realtime:hh:$householdId');

    // 1. Listen for Room changes
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Room',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'household_id',
        value: householdId,
      ),
      callback: (payload) async {
        final eventType = payload.eventType;
        if (eventType == PostgresChangeEvent.delete) {
          final id = payload.oldRecord['id'] as String?;
          if (id != null) {
            await (db.delete(db.roomsTable)..where((t) => t.id.equals(id))).go();
            await (db.delete(db.furnitureItemsTable)..where((t) => t.roomId.equals(id))).go();
            await (db.delete(db.tasksTable)..where((t) => t.referenceId.equals(id))).go();
          }
        } else {
          final record = payload.newRecord;
          if (record.isNotEmpty) {
            final dto = RoomDto.fromJson(record);
            await db.into(db.roomsTable).insertOnConflictUpdate(
              RoomsTableCompanion(
                id: Value(dto.id),
                householdId: Value(dto.householdId),
                name: Value(dto.name),
                floor: Value(dto.floor),
                polygonCoordinates: Value(jsonEncode(dto.polygonCoordinates)),
                cleanlinessScore: Value(dto.cleanlinessScore),
                createdAt: Value(dto.createdAt),
                updatedAt: Value(dto.updatedAt),
                isPendingSync: const Value(false),
              ),
            );
          }
        }
      },
    );

    // 2. Listen for Task changes
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Task',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'household_id',
        value: householdId,
      ),
      callback: (payload) async {
        final eventType = payload.eventType;
        if (eventType == PostgresChangeEvent.delete) {
          final id = payload.oldRecord['id'] as String?;
          if (id != null) {
            await (db.delete(db.tasksTable)..where((t) => t.id.equals(id))).go();
          }
        } else {
          final record = payload.newRecord;
          if (record.isNotEmpty) {
            final dto = TaskItemDto.fromJson(record);
            await db.into(db.tasksTable).insertOnConflictUpdate(
              TasksTableCompanion(
                id: Value(dto.id),
                householdId: Value(dto.householdId),
                title: Value(dto.title),
                description: Value(dto.description),
                referenceId: Value(dto.referenceId),
                referenceType: Value(dto.referenceType),
                assignedTo: Value(dto.assignedTo),
                status: Value(dto.status),
                pointsReward: Value(dto.pointsReward),
                dueDate: Value(dto.dueDate),
                completedAt: Value(dto.completedAt),
                createdAt: Value(dto.createdAt),
                updatedAt: Value(dto.updatedAt),
                isPendingSync: const Value(false),
              ),
            );
          }
        }
      },
    );

    // 3. Listen for Furniture_Item changes
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Furniture_Item',
      callback: (payload) async {
        final eventType = payload.eventType;
        if (eventType == PostgresChangeEvent.delete) {
          final id = payload.oldRecord['id'] as String?;
          if (id != null) {
            await (db.delete(db.furnitureItemsTable)..where((t) => t.id.equals(id))).go();
            await (db.delete(db.tasksTable)..where((t) => t.referenceId.equals(id))).go();
          }
        } else {
          final record = payload.newRecord;
          if (record.isNotEmpty) {
            final dto = FurnitureItemDto.fromJson(record);
            await db.into(db.furnitureItemsTable).insertOnConflictUpdate(
              FurnitureItemsTableCompanion(
                id: Value(dto.id),
                roomId: Value(dto.roomId),
                name: Value(dto.name),
                category: Value(dto.category),
                positionCoordinates: Value(jsonEncode(dto.positionCoordinates)),
                createdAt: Value(dto.createdAt),
                updatedAt: Value(dto.updatedAt),
                isPendingSync: const Value(false),
              ),
            );
          }
        }
      },
    );

    // 4. Listen for User changes (points total updates, new household members)
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'User',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'household_id',
        value: householdId,
      ),
      callback: (payload) async {
        onUserChanged?.call(householdId);
      },
    );

    channel.subscribe();
    _realtimeChannel = channel;
  }

  void unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      supabase?.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      _subscribedHouseholdId = null;
    }
  }

  // ===========================================================================
  // 1. FULL 2-WAY SYNCHRONIZATION (SYNC ALL)
  // ===========================================================================
  Future<void> syncAll({String? householdId}) async {
    if (_isSyncing) return;
    final isOnline = await connectivity.isConnected();
    if (!isOnline || supabase == null) return;

    _isSyncing = true;
    try {
      // Step 1: Upload local offline changes to the server (PUSH)
      await _pushPendingChanges();

      // Step 2: Download remote changes into local database (PULL)
      await _pullRemoteChanges(householdId: householdId ?? _subscribedHouseholdId);
    } catch (_) {
      // If network fails, local data is preserved and retried on next connection
    } finally {
      _isSyncing = false;
    }
  }

  // ===========================================================================
  // 2. PUSH: UPLOAD LOCAL OFFLINE MUTATIONS TO SUPABASE
  // ===========================================================================
  Future<void> _pushPendingChanges() async {
    final client = supabase;
    if (client == null) return;

    // Fetch queued changes in FIFO order
    final queueEntries = await (db.select(db.syncQueueTable)
          ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc)]))
        .get();

    for (final item in queueEntries) {
      try {
        if (item.targetTable == 'Task') {
          if (item.operation == 'DELETE') {
            await client.from('Task').delete().eq('id', item.recordId);
          } else {
            final jsonMap = jsonDecode(item.payload) as Map<String, dynamic>;
            final hhId = jsonMap['household_id'];
            if (hhId != null) {
              await client.from('Household').upsert({
                'id': hhId,
                'name': 'Family Home',
              });
            }
            await client.from('Task').upsert(jsonMap);
            // Clear pending flag on successful push
            await (db.update(db.tasksTable)..where((t) => t.id.equals(item.recordId)))
                .write(const TasksTableCompanion(isPendingSync: Value(false)));
          }
        } else if (item.targetTable == 'Room') {
          if (item.operation == 'DELETE') {
            await client.from('Room').delete().eq('id', item.recordId);
          } else {
            final jsonMap = jsonDecode(item.payload) as Map<String, dynamic>;
            final hhId = jsonMap['household_id'];
            if (hhId != null) {
              await client.from('Household').upsert({
                'id': hhId,
                'name': 'Family Home',
              });
            }
            await client.from('Room').upsert(jsonMap);
            await (db.update(db.roomsTable)..where((t) => t.id.equals(item.recordId)))
                .write(const RoomsTableCompanion(isPendingSync: Value(false)));
          }
        } else if (item.targetTable == 'Furniture_Item') {
          if (item.operation == 'DELETE') {
            await client.from('Furniture_Item').delete().eq('id', item.recordId);
          } else {
            final jsonMap = jsonDecode(item.payload) as Map<String, dynamic>;
            await client.from('Furniture_Item').upsert(jsonMap);
            await (db.update(db.furnitureItemsTable)..where((t) => t.id.equals(item.recordId)))
                .write(const FurnitureItemsTableCompanion(isPendingSync: Value(false)));
          }
        }

        // Remove processed item from sync queue
        await (db.delete(db.syncQueueTable)..where((t) => t.id.equals(item.id))).go();
      } catch (_) {
        // Stop queue processing on error; retry during next sync cycle
        break;
      }
    }
  }

  // ===========================================================================
  // 3. PULL: DOWNLOAD REMOTE DATA AND UPDATE DRIFT
  // ===========================================================================
  Future<void> _pullRemoteChanges({String? householdId}) async {
    final client = supabase;
    if (client == null) return;

    final effectiveHhId = householdId ?? _subscribedHouseholdId;

    // A) Download Rooms
    List<dynamic> remoteRooms = [];
    try {
      final roomQuery = client.from('Room').select();
      final res = await (effectiveHhId != null && effectiveHhId.isNotEmpty
          ? roomQuery.eq('household_id', effectiveHhId)
          : roomQuery);
      remoteRooms = res as List;

      for (final raw in remoteRooms) {
        final dto = RoomDto.fromJson(raw as Map<String, dynamic>);

        final localRoom = await (db.select(db.roomsTable)..where((t) => t.id.equals(dto.id)))
            .getSingleOrNull();

        if (localRoom != null && localRoom.isPendingSync) {
          // Local draft takes priority; do not overwrite
          continue;
        }

        await db.into(db.roomsTable).insertOnConflictUpdate(
          RoomsTableCompanion(
            id: Value(dto.id),
            householdId: Value(dto.householdId),
            name: Value(dto.name),
            floor: Value(dto.floor),
            polygonCoordinates: Value(jsonEncode(dto.polygonCoordinates)),
            cleanlinessScore: Value(dto.cleanlinessScore),
            createdAt: Value(dto.createdAt),
            updatedAt: Value(dto.updatedAt),
            isPendingSync: const Value(false),
          ),
        );
      }
    } catch (_) {}

    // B) Download Tasks
    try {
      final taskQuery = client.from('Task').select();
      final remoteTasks = await (effectiveHhId != null && effectiveHhId.isNotEmpty
          ? taskQuery.eq('household_id', effectiveHhId)
          : taskQuery);
      for (final raw in (remoteTasks as List)) {
        final dto = TaskItemDto.fromJson(raw as Map<String, dynamic>);

        final localTask = await (db.select(db.tasksTable)..where((t) => t.id.equals(dto.id)))
            .getSingleOrNull();

        if (localTask != null && localTask.isPendingSync) {
          continue;
        }

        await db.into(db.tasksTable).insertOnConflictUpdate(
          TasksTableCompanion(
            id: Value(dto.id),
            householdId: Value(dto.householdId),
            title: Value(dto.title),
            description: Value(dto.description),
            referenceId: Value(dto.referenceId),
            referenceType: Value(dto.referenceType),
            assignedTo: Value(dto.assignedTo),
            status: Value(dto.status),
            pointsReward: Value(dto.pointsReward),
            dueDate: Value(dto.dueDate),
            completedAt: Value(dto.completedAt),
            createdAt: Value(dto.createdAt),
            updatedAt: Value(dto.updatedAt),
            isPendingSync: const Value(false),
          ),
        );
      }
    } catch (_) {}

    // C) Download Furniture Items
    try {
      final roomIds = remoteRooms.map((r) => r['id'] as String).toList();
      if (roomIds.isNotEmpty) {
        final remoteFurniture = await client
            .from('Furniture_Item')
            .select()
            .inFilter('room_id', roomIds);

        for (final raw in (remoteFurniture as List)) {
          final dto = FurnitureItemDto.fromJson(raw as Map<String, dynamic>);
          final localItem = await (db.select(db.furnitureItemsTable)..where((t) => t.id.equals(dto.id)))
              .getSingleOrNull();

          if (localItem != null && localItem.isPendingSync) {
            continue;
          }

          await db.into(db.furnitureItemsTable).insertOnConflictUpdate(
            FurnitureItemsTableCompanion(
              id: Value(dto.id),
              roomId: Value(dto.roomId),
              name: Value(dto.name),
              category: Value(dto.category),
              positionCoordinates: Value(jsonEncode(dto.positionCoordinates)),
              createdAt: Value(dto.createdAt),
              updatedAt: Value(dto.updatedAt),
              isPendingSync: const Value(false),
            ),
          );
        }
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 4. OFFLINE-FIRST MUTATION OPERATIONS (ROOMS)
  // ===========================================================================

  /// Save room (offline: Drift + SyncQueue, online: immediate Supabase sync)
  Future<void> saveRoom(Room room) async {
    final isOnline = await connectivity.isConnected();
    final dto = RoomDto.fromDomain(room);

    // 1. Save to local SQLite database
    await db.into(db.roomsTable).insertOnConflictUpdate(
      RoomsTableCompanion(
        id: Value(room.id),
        householdId: Value(room.householdId),
        name: Value(room.name),
        floor: Value(room.floor),
        polygonCoordinates: Value(jsonEncode(room.polygonCoordinates)),
        cleanlinessScore: Value(room.cleanlinessScore),
        createdAt: Value(room.createdAt),
        updatedAt: Value(room.updatedAt),
        isPendingSync: Value(!isOnline),
      ),
    );

    // 2. If online, sync immediately
    if (isOnline && supabase != null) {
      try {
        await supabase!.from('Room').upsert(dto.toJson());
        return;
      } catch (_) {}
    }

    // 3. Fallback to offline sync queue
    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion(
        targetTable: const Value('Room'),
        recordId: Value(room.id),
        operation: const Value('INSERT'),
        payload: Value(jsonEncode(dto.toJson())),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete room (local cascade: furniture + tasks, then room + Supabase sync)
  Future<void> deleteRoom(String roomId) async {
    final isOnline = await connectivity.isConnected();

    // 1. Local cascade delete:
    // First, find all furniture in this room so we can cascade-delete their tasks too
    final roomFurniture = await (db.select(db.furnitureItemsTable)..where((t) => t.roomId.equals(roomId))).get();
    final furnitureIds = roomFurniture.map((f) => f.id).toList();

    if (furnitureIds.isNotEmpty) {
      await (db.delete(db.tasksTable)..where((t) => t.referenceId.isIn(furnitureIds))).go();
    }
    await (db.delete(db.furnitureItemsTable)..where((t) => t.roomId.equals(roomId))).go();
    await (db.delete(db.tasksTable)..where((t) => t.referenceId.equals(roomId))).go();
    await (db.delete(db.roomsTable)..where((t) => t.id.equals(roomId))).go();

    // 2. If online, sync delete
    if (isOnline && supabase != null) {
      try {
        await supabase!.from('Room').delete().eq('id', roomId);
        return;
      } catch (_) {}
    }

    // 3. Fallback to sync queue
    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion(
        targetTable: const Value('Room'),
        recordId: Value(roomId),
        operation: const Value('DELETE'),
        payload: Value(jsonEncode({'id': roomId})),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update room cleanliness index (0-100)
  Future<void> updateRoomCleanliness(String roomId, int score) async {
    final isOnline = await connectivity.isConnected();
    final clamped = score.clamp(0, 100);

    await (db.update(db.roomsTable)..where((t) => t.id.equals(roomId))).write(
      RoomsTableCompanion(
        cleanlinessScore: Value(clamped),
        updatedAt: Value(DateTime.now()),
        isPendingSync: Value(!isOnline),
      ),
    );

    if (isOnline && supabase != null) {
      try {
        await supabase!.from('Room').update({
          'cleanliness_score': clamped,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', roomId);
        return;
      } catch (_) {}
    }

    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion(
        targetTable: const Value('Room'),
        recordId: Value(roomId),
        operation: const Value('UPDATE'),
        payload: Value(jsonEncode({
          'id': roomId,
          'cleanliness_score': clamped,
          'updated_at': DateTime.now().toIso8601String(),
        })),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  // ===========================================================================
  // 5. OFFLINE-FIRST MUTATION OPERATIONS (TASKS)
  // ===========================================================================

  /// Save task (offline: Drift + SyncQueue, online: immediate sync)
  Future<void> saveTask(TaskItem task) async {
    final isOnline = await connectivity.isConnected();
    final dto = TaskItemDto.fromDomain(task);

    await db.into(db.tasksTable).insertOnConflictUpdate(
      TasksTableCompanion(
        id: Value(task.id),
        householdId: Value(task.householdId),
        title: Value(task.title),
        description: Value(task.description),
        referenceId: Value(task.referenceId),
        referenceType: Value(task.referenceType.value),
        assignedTo: Value(task.assignedTo),
        status: Value(task.status.value),
        pointsReward: Value(task.pointsReward),
        dueDate: Value(task.dueDate),
        completedAt: Value(task.completedAt),
        createdAt: Value(task.createdAt),
        updatedAt: Value(task.updatedAt),
        isPendingSync: Value(!isOnline),
      ),
    );

    if (isOnline && supabase != null) {
      try {
        await supabase!.from('Task').upsert(dto.toJson());
        return;
      } catch (_) {}
    }

    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion(
        targetTable: const Value('Task'),
        recordId: Value(task.id),
        operation: const Value('INSERT'),
        payload: Value(jsonEncode(dto.toJson())),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Toggle task status (e.g. complete recurring or one-time task)
  Future<({int points, String? awardee})?> toggleTaskStatus(String taskId, TaskStatus currentStatus, {String? completedBy}) async {
    final isOnline = await connectivity.isConnected();
    final now = DateTime.now();

    // Check if task is recurring
    final localRow = await (db.select(db.tasksTable)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    final taskItem = localRow != null
        ? TaskItem(
            id: localRow.id,
            householdId: localRow.householdId,
            title: localRow.title,
            description: localRow.description,
            referenceId: localRow.referenceId,
            referenceType: TaskReferenceType.fromString(localRow.referenceType),
            assignedTo: localRow.assignedTo,
            status: TaskStatus.fromString(localRow.status),
            pointsReward: localRow.pointsReward,
            dueDate: localRow.dueDate,
            completedAt: localRow.completedAt,
            createdAt: localRow.createdAt,
            updatedAt: localRow.updatedAt,
          )
        : null;

    TaskStatus newStatus;
    DateTime? newDueDate = taskItem?.dueDate;
    DateTime? completedAt;
    String? newDescription = taskItem?.description;
    int pointsToAward = 0;
    String? awardee;

    if (taskItem != null && taskItem.isRecurring && currentStatus != TaskStatus.completed) {
      // Recurring task completed -> restart cycle immediately with new due date
      final interval = taskItem.repeatIntervalMinutes ?? 1440;
      newDueDate = now.add(Duration(minutes: interval));
      newStatus = TaskStatus.pending;
      completedAt = null;

      pointsToAward = taskItem.pointsReward > 0 ? taskItem.pointsReward : 10;
      awardee = completedBy ?? taskItem.assignedTo;

      // Append to completionHistory (keep last 2-3 entries)
      final history = List<Map<String, dynamic>>.from(taskItem.completionHistory);
      final member = completedBy ?? taskItem.assignedTo ?? 'Family Member';
      history.insert(0, {
        'by': member,
        'at': now.toIso8601String(),
      });
      final trimmedHistory = history.take(2).toList();
      newDescription = TaskItem.packDescription(
        priority: taskItem.priority,
        isRecurring: taskItem.isRecurring,
        repeatIntervalMinutes: taskItem.repeatIntervalMinutes,
        notes: taskItem.notes,
        completionHistory: trimmedHistory,
      );
    } else {
      newStatus = currentStatus == TaskStatus.completed
          ? TaskStatus.pending
          : TaskStatus.completed;
      completedAt = newStatus == TaskStatus.completed ? now : null;

      if (taskItem != null && newStatus == TaskStatus.completed) {
        pointsToAward = taskItem.pointsReward > 0 ? taskItem.pointsReward : 10;
        awardee = completedBy ?? taskItem.assignedTo;
      }
    }

    // Immediate local update in Drift
    await (db.update(db.tasksTable)..where((t) => t.id.equals(taskId))).write(
      TasksTableCompanion(
        description: Value(newDescription),
        status: Value(newStatus.value),
        dueDate: Value(newDueDate),
        completedAt: Value(completedAt),
        updatedAt: Value(now),
        isPendingSync: Value(!isOnline),
      ),
    );

    // Persist points increment to Supabase User table if online
    if (pointsToAward > 0 && awardee != null && awardee.isNotEmpty) {
      if (isOnline && supabase != null) {
        try {
          final existingUser = await supabase!
              .from('User')
              .select('id, points_total')
              .or('id.eq.$awardee,name.ilike.$awardee')
              .limit(1)
              .maybeSingle();

          if (existingUser != null) {
            final cur = (existingUser['points_total'] as num?)?.toInt() ?? 0;
            await supabase!.from('User').update({
              'points_total': cur + pointsToAward,
              'updated_at': now.toIso8601String(),
            }).eq('id', existingUser['id']);
          }
        } catch (_) {}
      }
    }

    final payload = {
      'id': taskId,
      'description': newDescription,
      'status': newStatus.value,
      'due_date': newDueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    if (isOnline && supabase != null) {
      try {
        await supabase!.from('Task').update(payload).eq('id', taskId);
        return (points: pointsToAward, awardee: awardee);
      } catch (_) {}
    }

    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion(
        targetTable: const Value('Task'),
        recordId: Value(taskId),
        operation: const Value('UPDATE'),
        payload: Value(jsonEncode(payload)),
        createdAt: Value(now),
      ),
    );

    return (points: pointsToAward, awardee: awardee);
  }

  /// Clear all local Drift database tables (e.g. on logout or fresh start)
  Future<void> clearAllLocalData() async {
    await db.delete(db.syncQueueTable).go();
    await db.delete(db.tasksTable).go();
    await db.delete(db.furnitureItemsTable).go();
    await db.delete(db.roomsTable).go();
    await db.delete(db.usersTable).go();
    await db.delete(db.householdsTable).go();
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    final isOnline = await connectivity.isConnected();

    // Delete locally from Drift
    await (db.delete(db.tasksTable)..where((t) => t.id.equals(taskId))).go();

    if (isOnline && supabase != null) {
      try {
        await supabase!.from('Task').delete().eq('id', taskId);
        return;
      } catch (_) {}
    }

    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion(
        targetTable: const Value('Task'),
        recordId: Value(taskId),
        operation: const Value('DELETE'),
        payload: Value(jsonEncode({'id': taskId})),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  // ===========================================================================
  // 6. REACTIVE OFFLINE-FIRST STREAMS (UI READS DIRECTLY FROM DRIFT)
  // ===========================================================================

  Stream<List<Room>> watchLocalRooms({String? householdId}) {
    final query = db.select(db.roomsTable);
    if (householdId != null && householdId.isNotEmpty) {
      query.where((t) => t.householdId.equals(householdId));
    }
    return query.watch().map((rows) {
      return rows.map((row) {
        List<dynamic> coords = [];
        try {
          coords = jsonDecode(row.polygonCoordinates) as List<dynamic>;
        } catch (_) {}

        return Room(
          id: row.id,
          householdId: row.householdId,
          name: row.name,
          floor: row.floor,
          polygonCoordinates: coords,
          cleanlinessScore: row.cleanlinessScore,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
      }).toList();
    });
  }

  Stream<List<TaskItem>> watchLocalTasks({String? householdId}) {
    final query = db.select(db.tasksTable);
    if (householdId != null && householdId.isNotEmpty) {
      query.where((t) => t.householdId.equals(householdId));
    }
    return query.watch().map((rows) {
      return rows.map((row) {
        return TaskItem(
          id: row.id,
          householdId: row.householdId,
          title: row.title,
          description: row.description,
          referenceId: row.referenceId,
          referenceType: TaskReferenceType.fromString(row.referenceType),
          assignedTo: row.assignedTo,
          status: TaskStatus.fromString(row.status),
          pointsReward: row.pointsReward,
          dueDate: row.dueDate,
          completedAt: row.completedAt,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
      }).toList();
    });
  }

  Stream<List<FurnitureItem>> watchLocalFurnitureItems({String? roomId, String? householdId}) {
    final query = db.select(db.furnitureItemsTable);
    if (roomId != null) {
      query.where((t) => t.roomId.equals(roomId));
    }
    return query.watch().map((rows) {
      return rows.map((row) {
        Map<String, dynamic> coords = {};
        try {
          coords = jsonDecode(row.positionCoordinates) as Map<String, dynamic>;
        } catch (_) {}
        return FurnitureItem(
          id: row.id,
          roomId: row.roomId,
          name: row.name,
          category: row.category,
          positionCoordinates: coords,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
      }).toList();
    });
  }

  /// Save furniture item
  Future<void> saveFurnitureItem(FurnitureItem item) async {
    final isOnline = await connectivity.isConnected();
    final dto = FurnitureItemDto.fromDomain(item);

    await db.into(db.furnitureItemsTable).insertOnConflictUpdate(
      FurnitureItemsTableCompanion(
        id: Value(item.id),
        roomId: Value(item.roomId),
        name: Value(item.name),
        category: Value(item.category),
        positionCoordinates: Value(jsonEncode(item.positionCoordinates)),
        createdAt: Value(item.createdAt),
        updatedAt: Value(item.updatedAt),
        isPendingSync: Value(!isOnline),
      ),
    );

    if (isOnline && supabase != null) {
      try {
        await supabase!.from('Furniture_Item').upsert(dto.toJson());
        return;
      } catch (_) {}
    }

    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion(
        targetTable: const Value('Furniture_Item'),
        recordId: Value(item.id),
        operation: const Value('INSERT'),
        payload: Value(jsonEncode(dto.toJson())),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete furniture item
  Future<void> deleteFurnitureItem(String itemId) async {
    final isOnline = await connectivity.isConnected();
    // Cascade delete any tasks referencing this furniture item
    await (db.delete(db.tasksTable)..where((t) => t.referenceId.equals(itemId))).go();
    await (db.delete(db.furnitureItemsTable)..where((t) => t.id.equals(itemId))).go();

    if (isOnline && supabase != null) {
      try {
        await supabase!.from('Furniture_Item').delete().eq('id', itemId);
        return;
      } catch (_) {}
    }

    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion(
        targetTable: const Value('Furniture_Item'),
        recordId: Value(itemId),
        operation: const Value('DELETE'),
        payload: Value(jsonEncode({'id': itemId})),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Count of pending items waiting to sync
  Stream<int> watchPendingSyncCount() {
    return db.select(db.syncQueueTable).watch().map((items) => items.length);
  }
}

/// Riverpod provider for SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final connectivity = ref.watch(connectivityServiceProvider);

  final service = SyncService(
    db: db,
    supabase: supabase,
    connectivity: connectivity,
  );

  ref.onDispose(() => service.dispose());
  return service;
});

/// Reactive local rooms provider (Offline-first Drift)
final localRoomsStreamProvider = StreamProvider<List<Room>>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.watchLocalRooms();
});

/// Reactive local tasks provider (Offline-first Drift)
final localTasksStreamProvider = StreamProvider<List<TaskItem>>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.watchLocalTasks();
});

/// Reactive local furniture provider (Offline-first Drift)
final localFurnitureStreamProvider = StreamProvider<List<FurnitureItem>>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.watchLocalFurnitureItems();
});

/// Pending sync count provider
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.watchPendingSyncCount();
});
