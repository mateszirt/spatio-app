import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/reward.dart';
import 'household_state_provider.dart';

/// Realtime Stream of Active Custom Rewards for the Household
final householdRewardsStreamProvider = StreamProvider<List<Reward>>((ref) {
  final supabase = Supabase.instance.client;
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null || householdId.isEmpty) {
    return Stream.value([]);
  }

  return supabase
      .from('Reward')
      .stream(primaryKey: ['id'])
      .eq('household_id', householdId)
      .map((rows) {
        return rows
            .where((r) => r['is_active'] != false)
            .map((r) => Reward.fromJson(r))
            .toList()
          ..sort((a, b) => a.cost.compareTo(b.cost));
      });
});

/// Realtime Stream of Reward Redemptions (Claims) for the Household
final householdRedemptionsStreamProvider =
    StreamProvider<List<RewardRedemption>>((ref) {
  final supabase = Supabase.instance.client;
  final householdId = ref.watch(currentHouseholdIdProvider);
  if (householdId == null || householdId.isEmpty) {
    return Stream.value([]);
  }

  return supabase
      .from('Reward_Redemption')
      .stream(primaryKey: ['id'])
      .eq('household_id', householdId)
      .map((rows) {
        return rows.map((r) => RewardRedemption.fromJson(r)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
});

class RewardsController extends Notifier<void> {
  @override
  void build() {}

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Create a new custom reward (Parents only)
  Future<void> createReward({
    required String title,
    String? description,
    required String emoji,
    required int cost,
    int? stock,
  }) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    final currentUser = ref.read(currentUserProvider);
    if (householdId == null) throw Exception('No active household');

    final safeCost = cost < 0 ? 0 : cost;
    await _supabase.from('Reward').insert({
      'household_id': householdId,
      'title': title,
      'description': description,
      'emoji': emoji,
      'cost': safeCost,
      'stock': stock,
      'is_active': true,
      'created_by': currentUser?.id,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Delete or deactivate a reward (Parents only)
  Future<void> deleteReward(String rewardId) async {
    await _supabase.from('Reward').update({
      'is_active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', rewardId);
  }

  /// Update existing reward details (Parents only)
  Future<void> updateReward({
    required String rewardId,
    required String title,
    String? description,
    required String emoji,
    required int cost,
    int? stock,
  }) async {
    final safeCost = cost < 0 ? 0 : cost;
    await _supabase.from('Reward').update({
      'title': title,
      'description': description,
      'emoji': emoji,
      'cost': safeCost,
      'stock': stock,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', rewardId);
  }

  /// Redeem a reward with earned points (Kids or Family members)
  Future<({bool success, String message, int remainingPoints})> redeemReward(
      Reward reward) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      return (success: false, message: 'You must be logged in to redeem.', remainingPoints: 0);
    }

    if (reward.isSoldOut) {
      return (
        success: false,
        message: 'This reward is currently out of stock!',
        remainingPoints: currentUser.points,
      );
    }

    if (currentUser.points < reward.cost) {
      return (
        success: false,
        message: 'Not enough points! You have ${currentUser.points} pts, but this reward costs ${reward.cost} pts.',
        remainingPoints: currentUser.points
      );
    }

    try {
      // Call atomic redeem_reward RPC
      final response = await _supabase.rpc('redeem_reward', params: {
        'p_reward_id': reward.id,
        'p_user_id': currentUser.id,
      });

      final remaining = (response['remaining_points'] as num?)?.toInt() ??
          (currentUser.points - reward.cost);

      // Immediately deduct points locally
      ref.read(currentUserProvider.notifier).deductPoints(reward.cost);
      ref.read(householdMembersProvider.notifier).deductPointsFromMember(currentUser.id, reward.cost);

      return (
        success: true,
        message: 'Successfully redeemed "${reward.title}"! Ask a parent to hand it over.',
        remainingPoints: remaining
      );
    } catch (e) {
      // Fallback manual redemption if RPC fails
      try {
        final householdId = ref.read(currentHouseholdIdProvider);
        await _supabase.from('Reward_Redemption').insert({
          'household_id': householdId,
          'reward_id': reward.id,
          'user_id': currentUser.id,
          'reward_title': reward.title,
          'reward_emoji': reward.emoji,
          'cost': reward.cost,
          'status': 'pending',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Deduct points from User table
        await _supabase.from('User').update({
          'points_total': currentUser.points - reward.cost,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', currentUser.id);

        ref.read(currentUserProvider.notifier).deductPoints(reward.cost);
        ref.read(householdMembersProvider.notifier).deductPointsFromMember(currentUser.id, reward.cost);

        return (
          success: true,
          message: 'Successfully claimed "${reward.title}"!',
          remainingPoints: currentUser.points - reward.cost
        );
      } catch (err) {
        return (success: false, message: 'Failed to redeem reward: $err', remainingPoints: currentUser.points);
      }
    }
  }

  /// Fulfill / Hand over a pending reward to child (Parents only)
  Future<void> fulfillRedemption(String redemptionId) async {
    try {
      await _supabase.rpc('fulfill_redemption', params: {
        'p_redemption_id': redemptionId,
      });
    } catch (_) {
      // Direct table update fallback
      await _supabase.from('Reward_Redemption').update({
        'status': 'fulfilled',
        'fulfilled_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', redemptionId);
    }
  }
}

final rewardsControllerProvider =
    NotifierProvider<RewardsController, void>(RewardsController.new);
