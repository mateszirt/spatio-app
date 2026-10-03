import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/cleaning_tasks/presentation/controllers/household_state_provider.dart';
import 'auth_service.dart';

/// Represents the real-time presence activity of a family member
class UserPresence {
  final String userId;
  final String userName;
  final String userAvatar;
  final String action; // 'placing_furniture', 'typing_task', 'drawing_room', 'idle'
  final String? detail; // e.g. 'Placing Double Bed'
  final String? roomId;
  final int? floor;
  final DateTime updatedAt;

  const UserPresence({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.action,
    this.detail,
    this.roomId,
    this.floor,
    required this.updatedAt,
  });

  bool get isPlacingFurniture => action == 'placing_furniture';
  bool get isTypingTask => action == 'typing_task';
  bool get isDrawingRoom => action == 'drawing_room';
  bool get isBusy => action != 'idle' && detail != null && detail!.isNotEmpty;

  String get displayStatus {
    if (detail != null && detail!.isNotEmpty) return detail!;
    if (isPlacingFurniture) return 'Placing furniture';
    if (isTypingTask) return 'Typing a task';
    if (isDrawingRoom) return 'Drawing a room';
    return 'Online';
  }

  factory UserPresence.fromMap(Map<String, dynamic> map) {
    return UserPresence(
      userId: map['user_id'] as String? ?? '',
      userName: map['user_name'] as String? ?? 'Family Member',
      userAvatar: map['user_avatar'] as String? ?? '👤',
      action: map['action'] as String? ?? 'idle',
      detail: map['detail'] as String?,
      roomId: map['room_id'] as String?,
      floor: (map['floor'] as num?)?.toInt(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'user_name': userName,
    'user_avatar': userAvatar,
    'action': action,
    'detail': detail,
    'room_id': roomId,
    'floor': floor,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// State notifier that tracks all active family member presences
class HouseholdPresenceNotifier extends Notifier<List<UserPresence>> {
  RealtimeChannel? _channel;
  String? _subscribedHouseholdId;
  Timer? _heartbeatTimer;

  @override
  List<UserPresence> build() {
    final authState = ref.watch(authProvider);
    final householdId = authState.householdId;

    if (householdId != null && householdId.isNotEmpty) {
      _subscribeToPresence(householdId);
    } else {
      _unsubscribe();
    }

    ref.onDispose(() {
      _unsubscribe();
    });

    return [];
  }

  void _subscribeToPresence(String householdId) {
    if (_subscribedHouseholdId == householdId && _channel != null) return;
    _unsubscribe();

    try {
      final client = Supabase.instance.client;
      _subscribedHouseholdId = householdId;
      _channel = client.channel('presence:hh:$householdId');

      _channel!.onPresenceSync((_) {
        _syncPresenceState();
      });

      _channel!.onPresenceJoin((payload) {
        _syncPresenceState();
      });

      _channel!.onPresenceLeave((payload) {
        _syncPresenceState();
      });

      _channel!.subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await trackActivity(action: 'idle');
        }
      });
    } catch (_) {}
  }

  void _syncPresenceState() {
    if (_channel == null) return;
    try {
      final currentMember = ref.read(currentUserProvider);
      final rawState = _channel!.presenceState();
      final List<UserPresence> list = [];

      for (final stateEntry in rawState) {
        for (final presence in stateEntry.presences) {
          final p = UserPresence.fromMap(presence.payload);
          // Only show other users, not self
          if (p.userId.isNotEmpty && (currentMember == null || p.userId != currentMember.id)) {
            list.add(p);
          }
        }
      }

      state = list;
    } catch (_) {}
  }

  /// Broadcast current user's activity in the household
  Future<void> trackActivity({
    required String action,
    String? detail,
    String? roomId,
    int? floor,
  }) async {
    if (_channel == null) return;
    final currentMember = ref.read(currentUserProvider);
    if (currentMember == null) return;

    final presence = UserPresence(
      userId: currentMember.id,
      userName: currentMember.name,
      userAvatar: currentMember.avatar,
      action: action,
      detail: detail,
      roomId: roomId,
      floor: floor,
      updatedAt: DateTime.now().toUtc(),
    );

    try {
      await _channel!.track(presence.toMap());
    } catch (_) {}
  }

  void _unsubscribe() {
    _heartbeatTimer?.cancel();
    if (_channel != null) {
      try {
        Supabase.instance.client.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
      _subscribedHouseholdId = null;
    }
  }
}

final householdPresenceProvider =
    NotifierProvider<HouseholdPresenceNotifier, List<UserPresence>>(
  HouseholdPresenceNotifier.new,
);
