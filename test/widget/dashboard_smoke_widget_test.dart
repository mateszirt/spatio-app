import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spatio_cleaning/main.dart';
import 'package:spatio_cleaning/core/services/connectivity_service.dart';
import 'package:spatio_cleaning/core/services/sync_service.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/controllers/supabase_sync_controller.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/room.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/task_item.dart';

import 'package:spatio_cleaning/core/services/auth_service.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/controllers/household_state_provider.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/controllers/task_assignment_controller.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        name: 'Parent User',
        role: 'parent',
        householdId: 'h-1',
      );
}

class FakeCurrentUserNotifier extends CurrentUserNotifier {
  @override
  FamilyMember? build() => const FamilyMember(
        id: 'u-1',
        name: 'Parent User',
        role: 'parent',
        avatar: '👩‍💼',
        email: 'parent@spatio.test',
      );
}

void main() {
  testWidgets('CleaningDashboardScreen smoke test with 2-way sync and offline/online streams', (WidgetTester tester) async {
    final sampleRoom = Room(
      id: 'room-1',
      householdId: 'h-1',
      name: 'Nappali',
      floor: 1,
      cleanlinessScore: 85,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleTask = TaskItem(
      id: 'task-1',
      householdId: 'h-1',
      title: 'Ablakpucolás',
      referenceId: 'room-1',
      referenceType: TaskReferenceType.room,
      pointsReward: 20,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier()),
          currentUserProvider.overrideWith(() => FakeCurrentUserNotifier()),
          roomsRealtimeStreamProvider.overrideWith((ref) => Stream.value([sampleRoom])),
          tasksRealtimeStreamProvider.overrideWith((ref) => Stream.value([sampleTask])),
          furnitureRealtimeStreamProvider.overrideWith((ref) => Stream.value([])),
          pendingApprovalTasksProvider.overrideWith((ref) => []),
          isOnlineStreamProvider.overrideWith((ref) => Stream.value(true)),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: const CleaningApp(),
      ),
    );

    await tester.pump();

    // Header, Online status, and Floor Plan tab checks
    expect(find.text('Spatio'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Floor Plan'), findsOneWidget);

    // Switch to Rooms tab
    await tester.tap(find.text('Rooms (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Nappali'), findsOneWidget);
    // Dynamic cleanliness engine computes 90% for 1 pending priority 3 task
    expect(find.text('90%'), findsOneWidget);

    // Open Account screen via top-right profile avatar button
    await tester.tap(find.byKey(const ValueKey('profile_avatar_button')));
    await tester.pumpAndSettle();

    expect(find.text('Security & Password'), findsOneWidget);
    expect(find.text('Danger Zone'), findsOneWidget);
  });
}
