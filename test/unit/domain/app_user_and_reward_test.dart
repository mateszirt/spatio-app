import 'package:flutter_test/flutter_test.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/app_user.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/reward.dart';
import 'package:cleaning_app/features/cleaning_tasks/domain/models/user_effort_snapshot.dart';

void main() {
  group('AppUser, UserRole, Reward and UserEffortSnapshot Tests', () {
    final now = DateTime(2026, 10, 3, 12, 0, 0);

    test('UserRole fromString mapping and case insensitivity', () {
      expect(UserRole.fromString('admin'), equals(UserRole.admin));
      expect(UserRole.fromString('Admin'), equals(UserRole.admin));
      expect(UserRole.fromString('ADMIN'), equals(UserRole.admin));
      expect(UserRole.fromString('child'), equals(UserRole.child));
      expect(UserRole.fromString('Child'), equals(UserRole.child));
      expect(UserRole.fromString('CHILD'), equals(UserRole.child));
      expect(UserRole.fromString('unknown_role'), equals(UserRole.child));
      expect(UserRole.fromString(''), equals(UserRole.child));
    });

    test('AppUser properties and role predicates', () {
      final parent = AppUser(
        id: 'u-parent',
        householdId: 'hh-1',
        name: 'Sarah',
        email: 'sarah@example.com',
        role: UserRole.admin,
        avatarUrl: '👩‍💼',
        pointsTotal: 350,
        createdAt: now,
      );

      expect(parent.isAdmin, isTrue);
      expect(parent.isChild, isFalse);
      expect(parent.pointsTotal, equals(350));
      expect(parent.email, equals('sarah@example.com'));

      final child = AppUser(
        id: 'u-child',
        householdId: 'hh-1',
        name: 'Leo',
        role: UserRole.child,
        createdAt: now,
      );

      expect(child.isAdmin, isFalse);
      expect(child.isChild, isTrue);
      expect(child.pointsTotal, equals(0)); // default 0
      expect(child.email, isNull);
      expect(child.avatarUrl, isNull);
    });

    test('Reward isSoldOut logic', () {
      final unlimited = Reward(
        id: 'r-unlim',
        householdId: 'hh-1',
        title: 'Unlimited Ice Cream',
        emoji: '🍦',
        cost: 30,
        stock: null,
        createdAt: now,
      );
      expect(unlimited.isSoldOut, isFalse);

      final inStock = Reward(
        id: 'r-stock',
        householdId: 'hh-1',
        title: 'Lego Set',
        emoji: '🧱',
        cost: 200,
        stock: 3,
        createdAt: now,
      );
      expect(inStock.isSoldOut, isFalse);

      final zeroStock = Reward(
        id: 'r-zero',
        householdId: 'hh-1',
        title: 'Theme Park Trip',
        emoji: '🎢',
        cost: 500,
        stock: 0,
        createdAt: now,
      );
      expect(zeroStock.isSoldOut, isTrue);

      final negativeStock = Reward(
        id: 'r-neg',
        householdId: 'hh-1',
        title: 'Concert Ticket',
        emoji: '🎟️',
        cost: 100,
        stock: -1,
        createdAt: now,
      );
      expect(negativeStock.isSoldOut, isTrue);
    });

    test('Reward.fromJson parsing valid, minimal and malformed payloads', () {
      final jsonFull = {
        'id': 'rew-1',
        'household_id': 'hh-1',
        'title': 'Cinema Trip',
        'description': 'Watch any movie on weekend',
        'emoji': '🎬',
        'cost': 80,
        'stock': 5,
        'is_active': true,
        'created_at': '2026-10-01T15:30:00.000Z',
      };

      final reward = Reward.fromJson(jsonFull);
      expect(reward.id, equals('rew-1'));
      expect(reward.householdId, equals('hh-1'));
      expect(reward.title, equals('Cinema Trip'));
      expect(reward.description, equals('Watch any movie on weekend'));
      expect(reward.emoji, equals('🎬'));
      expect(reward.cost, equals(80));
      expect(reward.stock, equals(5));
      expect(reward.isActive, isTrue);
      expect(reward.createdAt.year, equals(2026));

      // Minimal with missing optional fields & type conversion
      final jsonMinimal = {
        'id': 'rew-2',
        'household_id': 'hh-1',
        'cost': null, // null falls back to 0
        'created_at': 'invalid-date-format',
      };

      final rewardMinimal = Reward.fromJson(jsonMinimal);
      expect(rewardMinimal.title, equals(''));
      expect(rewardMinimal.emoji, equals('🎁'));
      expect(rewardMinimal.cost, equals(0)); // null falls back to 0
      expect(rewardMinimal.stock, isNull);
      expect(rewardMinimal.isActive, isTrue);
      expect(rewardMinimal.createdAt, isA<DateTime>());
    });

    test('RewardRedemption properties and fromJson status mapping', () {
      final jsonPending = {
        'id': 'red-1',
        'reward_id': 'rew-1',
        'user_id': 'u-child',
        'reward_title': 'Cinema Trip',
        'reward_emoji': '🎬',
        'cost': 80,
        'status': 'pending',
        'created_at': '2026-10-02T10:00:00.000Z',
        'fulfilled_at': null,
      };

      final redemptionPending = RewardRedemption.fromJson(jsonPending);
      expect(redemptionPending.id, equals('red-1'));
      expect(redemptionPending.rewardId, equals('rew-1'));
      expect(redemptionPending.userId, equals('u-child'));
      expect(redemptionPending.cost, equals(80));
      expect(redemptionPending.status, equals(RedemptionStatus.pending));
      expect(redemptionPending.isPending, isTrue);
      expect(redemptionPending.fulfilledAt, isNull);

      final jsonFulfilled = {
        'id': 'red-2',
        'reward_id': null, // e.g. deleted reward
        'user_id': 'u-child',
        'reward_title': 'Custom Ice Cream',
        'reward_emoji': '🍦',
        'cost': 30,
        'status': 'fulfilled',
        'created_at': '2026-10-02T10:00:00.000Z',
        'fulfilled_at': '2026-10-02T12:00:00.000Z',
      };

      final redemptionFulfilled = RewardRedemption.fromJson(jsonFulfilled);
      expect(redemptionFulfilled.status, equals(RedemptionStatus.fulfilled));
      expect(redemptionFulfilled.isPending, isFalse);
      expect(redemptionFulfilled.fulfilledAt, isNotNull);
    });

    test('UserEffortSnapshot role predicates, factory, equality and toString', () {
      final user = AppUser(
        id: 'u-10',
        householdId: 'hh-1',
        name: 'Alex',
        role: UserRole.admin,
        createdAt: now,
      );

      final snapshot = UserEffortSnapshot.fromUser(user, effortPoints: 85);
      expect(snapshot.userId, equals('u-10'));
      expect(snapshot.name, equals('Alex'));
      expect(snapshot.role, equals(UserRole.admin));
      expect(snapshot.effortPoints, equals(85));
      expect(snapshot.isAdult, isTrue);
      expect(snapshot.isChild, isFalse);

      final snapshotClone = UserEffortSnapshot(
        userId: 'u-10',
        name: 'Different Name',
        role: UserRole.admin,
        effortPoints: 200,
      );

      expect(snapshot, equals(snapshotClone)); // Equal by userId
      expect(snapshot.hashCode, equals(snapshotClone.hashCode));
      expect(snapshot.toString(), contains('effortPoints: 85'));

      final childSnapshot = UserEffortSnapshot(
        userId: 'u-child',
        name: 'Tim',
        role: UserRole.child,
        effortPoints: 10,
      );
      expect(childSnapshot.isAdult, isFalse);
      expect(childSnapshot.isChild, isTrue);
    });
  });
}
