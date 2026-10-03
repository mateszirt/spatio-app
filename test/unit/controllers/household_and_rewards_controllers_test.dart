import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/controllers/household_state_provider.dart';
import 'package:cleaning_app/features/cleaning_tasks/presentation/controllers/rewards_controller.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/reward.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HouseholdStateProvider & FamilyMember Unit Tests', () {
    test('FamilyMember role predicates and properties', () {
      const parent = FamilyMember(
        id: 'u-1',
        name: 'Parent Sarah',
        role: 'parent',
        avatar: '👩',
        email: 'sarah@example.com',
        points: 150,
      );
      expect(parent.isParent, isTrue);
      expect(parent.isChild, isFalse);
      expect(parent.points, equals(150));

      const admin = FamilyMember(
        id: 'u-admin',
        name: 'Admin Dad',
        role: 'admin',
        avatar: '👨',
        email: 'dad@example.com',
      );
      expect(admin.isParent, isTrue);
      expect(admin.isChild, isFalse);
      expect(admin.points, equals(0)); // default

      const child = FamilyMember(
        id: 'u-2',
        name: 'Little Tim',
        role: 'child',
        avatar: '🧒',
        email: 'tim@example.com',
        points: 40,
      );
      expect(child.isParent, isFalse);
      expect(child.isChild, isTrue);
    });

    test('HouseholdMembersNotifier addPointsToMember and deductPointsFromMember with boundary clamping', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(householdMembersProvider.notifier);

      final initialMembers = [
        const FamilyMember(id: 'm-1', name: 'Alice', role: 'parent', avatar: '👩', email: 'a@test.com', points: 100),
        const FamilyMember(id: 'm-2', name: 'Bob', role: 'child', avatar: '🧒', email: 'b@test.com', points: 50),
      ];
      notifier.setMembers(initialMembers);

      expect(container.read(householdMembersProvider).length, equals(2));

      // Add points by ID
      notifier.addPointsToMember('m-2', 30);
      expect(container.read(householdMembersProvider).firstWhere((m) => m.id == 'm-2').points, equals(80));

      // Add points by case-insensitive name
      notifier.addPointsToMember('alice', 50);
      expect(container.read(householdMembersProvider).firstWhere((m) => m.id == 'm-1').points, equals(150));

      // Adding 0 points does nothing (no needless state replacement)
      notifier.addPointsToMember('m-2', 0);
      expect(container.read(householdMembersProvider).firstWhere((m) => m.id == 'm-2').points, equals(80));

      // Deduct points
      notifier.deductPointsFromMember('m-2', 20);
      expect(container.read(householdMembersProvider).firstWhere((m) => m.id == 'm-2').points, equals(60));

      // Deduct more points than available -> clamps to 0
      notifier.deductPointsFromMember('bob', 999);
      expect(container.read(householdMembersProvider).firstWhere((m) => m.id == 'm-2').points, equals(0));

      // Deducting 0 points is a no-op
      notifier.deductPointsFromMember('bob', 0);
      expect(container.read(householdMembersProvider).firstWhere((m) => m.id == 'm-2').points, equals(0));
    });

    test('CurrentUserNotifier setUser, clear, addPoints, and deductPoints with zero clamping', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(currentUserProvider.notifier);
      expect(container.read(currentUserProvider), isNull);

      const user = FamilyMember(
        id: 'user-active',
        name: 'Eva',
        role: 'child',
        avatar: '👧',
        email: 'eva@test.com',
        points: 75,
      );

      notifier.setUser(user);
      expect(container.read(currentUserProvider)?.id, equals('user-active'));
      expect(container.read(currentUserProvider)?.points, equals(75));

      // Add points
      notifier.addPoints(25);
      expect(container.read(currentUserProvider)?.points, equals(100));

      // Adding 0 points has no effect
      notifier.addPoints(0);
      expect(container.read(currentUserProvider)?.points, equals(100));

      // Deduct points
      notifier.deductPoints(30);
      expect(container.read(currentUserProvider)?.points, equals(70));

      // Deduct with excess clamped to 0
      notifier.deductPoints(500);
      expect(container.read(currentUserProvider)?.points, equals(0));

      // Deducting 0 points has no effect
      notifier.deductPoints(0);
      expect(container.read(currentUserProvider)?.points, equals(0));

      // Clear user
      notifier.clear();
      expect(container.read(currentUserProvider), isNull);

      // Mutating null user does not crash
      notifier.addPoints(50);
      notifier.deductPoints(20);
      expect(container.read(currentUserProvider), isNull);
    });

    test('SelectedTaskPersonFilterNotifier filtering transitions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(selectedTaskPersonFilterProvider.notifier);
      expect(container.read(selectedTaskPersonFilterProvider), isNull);

      notifier.setFilter('user-1');
      expect(container.read(selectedTaskPersonFilterProvider), equals('user-1'));

      notifier.setFilter(null);
      expect(container.read(selectedTaskPersonFilterProvider), isNull);
    });

    test('resolveAssigneeName and resolveAssigneeAvatar handle empty, id, name match and fallback', () {
      final members = [
        const FamilyMember(id: 'u-101', name: 'Zoe', role: 'child', avatar: '🐱', email: 'z@test.com'),
        const FamilyMember(id: 'u-102', name: 'Mark', role: 'parent', avatar: '🦁', email: 'm@test.com'),
      ];

      // resolveAssigneeName
      expect(resolveAssigneeName(null, members), equals('Unassigned'));
      expect(resolveAssigneeName('', members), equals('Unassigned'));
      expect(resolveAssigneeName('   ', members), equals('Unassigned'));
      expect(resolveAssigneeName('u-101', members), equals('Zoe'));
      expect(resolveAssigneeName('zoe', members), equals('Zoe')); // case-insensitive name
      expect(resolveAssigneeName('MARK', members), equals('Mark'));
      expect(resolveAssigneeName('Guest Worker', members), equals('Guest Worker')); // Fallback to raw string

      // resolveAssigneeAvatar
      expect(resolveAssigneeAvatar(null, members), equals('👤'));
      expect(resolveAssigneeAvatar('', members), equals('👤'));
      expect(resolveAssigneeAvatar('u-101', members), equals('🐱'));
      expect(resolveAssigneeAvatar('zoe', members), equals('🐱'));
      expect(resolveAssigneeAvatar('MARK', members), equals('🦁'));
      expect(resolveAssigneeAvatar('Nonexistent', members), equals('👤'));
    });
  });

  group('RewardsController Validation & Business Logic Tests', () {
    test('redeemReward returns error when user is not logged in', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(rewardsControllerProvider.notifier);

      final reward = Reward(
        id: 'rew-icecream',
        householdId: 'hh-1',
        title: 'Ice Cream',
        emoji: '🍦',
        cost: 30,
        createdAt: DateTime.now(),
      );

      final result = await controller.redeemReward(reward);
      expect(result.success, isFalse);
      expect(result.message, contains('logged in'));
      expect(result.remainingPoints, equals(0));
    });

    test('redeemReward returns error when user has insufficient points', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set logged-in user with only 20 points
      container.read(currentUserProvider.notifier).setUser(
        const FamilyMember(
          id: 'u-child',
          name: 'Timmy',
          role: 'child',
          avatar: '🧒',
          email: 'timmy@test.com',
          points: 20,
        ),
      );

      final controller = container.read(rewardsControllerProvider.notifier);

      final reward = Reward(
        id: 'rew-bike',
        householdId: 'hh-1',
        title: 'Bike Ride',
        emoji: '🚲',
        cost: 50, // costs 50, but user only has 20
        createdAt: DateTime.now(),
      );

      final result = await controller.redeemReward(reward);
      expect(result.success, isFalse);
      expect(result.message, contains('Not enough points!'));
      expect(result.message, contains('have 20 pts'));
      // Verify points were NOT deducted
      expect(container.read(currentUserProvider)?.points, equals(20));
    });

    test('redeemReward returns error when reward is out of stock', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set logged-in user with plenty of points
      container.read(currentUserProvider.notifier).setUser(
        const FamilyMember(
          id: 'u-child',
          name: 'Timmy',
          role: 'child',
          avatar: '🧒',
          email: 'timmy@test.com',
          points: 500,
        ),
      );

      final controller = container.read(rewardsControllerProvider.notifier);

      final soldOutReward = Reward(
        id: 'rew-ticket',
        householdId: 'hh-1',
        title: 'Concert Ticket',
        emoji: '🎟️',
        cost: 100,
        stock: 0, // Out of stock!
        createdAt: DateTime.now(),
      );

      final result = await controller.redeemReward(soldOutReward);
      expect(result.success, isFalse);
      expect(result.message, contains('out of stock'));
      expect(result.remainingPoints, equals(500));

      // Verify points were NOT deducted
      expect(container.read(currentUserProvider)?.points, equals(500));
    });

    test('Negative point inputs are ignored and do not corrupt user balance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final memberNotifier = container.read(householdMembersProvider.notifier);
      memberNotifier.setMembers([
        const FamilyMember(id: 'm-1', name: 'Alice', role: 'parent', avatar: '👩', email: 'a@test.com', points: 100),
      ]);

      // Adding negative points is protected
      memberNotifier.addPointsToMember('m-1', -50);
      expect(container.read(householdMembersProvider).first.points, equals(100));

      // Deducting negative points is protected
      memberNotifier.deductPointsFromMember('m-1', -50);
      expect(container.read(householdMembersProvider).first.points, equals(100));

      final userNotifier = container.read(currentUserProvider.notifier);
      userNotifier.setUser(
        const FamilyMember(id: 'u-1', name: 'Alice', role: 'parent', avatar: '👩', email: 'a@test.com', points: 100),
      );

      userNotifier.addPoints(-30);
      expect(container.read(currentUserProvider)?.points, equals(100));

      userNotifier.deductPoints(-30);
      expect(container.read(currentUserProvider)?.points, equals(100));
    });
  });
}
