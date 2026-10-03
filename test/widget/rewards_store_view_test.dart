import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/widgets/rewards_store_view.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/controllers/household_state_provider.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/controllers/rewards_controller.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/reward.dart';

class MockCurrentUserNotifier extends CurrentUserNotifier {
  final FamilyMember? _initial;
  MockCurrentUserNotifier(this._initial);

  @override
  FamilyMember? build() => _initial;
}

class MockHouseholdMembersNotifier extends HouseholdMembersNotifier {
  final List<FamilyMember> _initial;
  MockHouseholdMembersNotifier(this._initial);

  @override
  List<FamilyMember> build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RewardsStoreView renders points balance, level progress, and rewards list',
      (WidgetTester tester) async {
    const mockUser = FamilyMember(
      id: 'u-child',
      name: 'Timmy',
      role: 'child',
      avatar: '🧒',
      email: 'timmy@test.com',
      points: 75,
    );

    final mockRewards = [
      Reward(
        id: 'rew-icecream',
        householdId: 'hh-1',
        title: 'Ice Cream Trip',
        emoji: '🍦',
        cost: 40,
        createdAt: DateTime.now(),
      ),
      Reward(
        id: 'rew-gametime',
        householdId: 'hh-1',
        title: '1 Hour Gaming',
        emoji: '🎮',
        cost: 100,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(() => MockCurrentUserNotifier(mockUser)),
          householdMembersProvider.overrideWith(() => MockHouseholdMembersNotifier(const [mockUser])),
          householdRewardsStreamProvider.overrideWith((ref) => Stream.value(mockRewards)),
          householdRedemptionsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RewardsStoreView(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Points Balance display
    expect(find.text('75'), findsWidgets);
    expect(find.text('Spendable Points'), findsOneWidget);

    // Verify rewards rendered
    expect(find.text('Ice Cream Trip'), findsOneWidget);
    expect(find.text('1 Hour Gaming'), findsOneWidget);
  });
}
