import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gamification.dart';
import '../../../../core/utils/top_snack_bar.dart';
import '../../../../core/widgets/task_celebration_overlay.dart';
import '../../domain/models/reward.dart';
import '../controllers/household_state_provider.dart';
import '../controllers/rewards_controller.dart';

class RewardsStoreView extends ConsumerStatefulWidget {
  const RewardsStoreView({super.key});

  @override
  ConsumerState<RewardsStoreView> createState() => _RewardsStoreViewState();
}

class _RewardsStoreViewState extends ConsumerState<RewardsStoreView> {
  final List<String> _emojiPresets = [
    '🍦', '🎮', '🎬', '🍕', '🧸', '🚲', '🍿', '🍩', '🎯', '🛌', '📱', '🎁'
  ];

  void _showCreateRewardDialog(BuildContext context, {Reward? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final costController = TextEditingController(text: existing?.cost.toString() ?? '50');
    final stockController = TextEditingController(text: existing?.stock?.toString() ?? '');
    String selectedEmoji = existing?.emoji ?? '🎁';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Text(selectedEmoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text(existing == null ? 'Create Custom Reward' : 'Edit Reward'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose an Icon / Emoji:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _emojiPresets.map((emoji) {
                    final isSel = selectedEmoji == emoji;
                    return InkWell(
                      onTap: () => setModalState(() => selectedEmoji = emoji),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                            width: isSel ? 2.0 : 1.0,
                          ),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Reward Title *',
                    hintText: 'e.g. 1 Hour Video Games, Ice Cream Trip',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cost in Points *',
                    hintText: 'e.g. 50',
                    prefixIcon: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g. Can be redeemed on weekends',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity / Stock (Optional, blank = unlimited)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final cost = int.tryParse(costController.text.trim()) ?? 0;
                final stock = int.tryParse(stockController.text.trim());
                if (title.isEmpty || cost <= 0) {
                  showTopSnackBar(context, 'Please enter a valid title and point cost', isError: true);
                  return;
                }

                Navigator.pop(ctx);
                try {
                  if (existing == null) {
                    await ref.read(rewardsControllerProvider.notifier).createReward(
                          title: title,
                          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                          emoji: selectedEmoji,
                          cost: cost,
                          stock: stock,
                        );
                    if (context.mounted) {
                      showTopSnackBar(context, '🎉 Custom reward created!');
                    }
                  } else {
                    await ref.read(rewardsControllerProvider.notifier).updateReward(
                          rewardId: existing.id,
                          title: title,
                          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                          emoji: selectedEmoji,
                          cost: cost,
                          stock: stock,
                        );
                    if (context.mounted) {
                      showTopSnackBar(context, 'Reward updated successfully');
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    showTopSnackBar(context, 'Error saving reward: $e', isError: true);
                  }
                }
              },
              child: Text(existing == null ? 'Create Reward' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRedeem(Reward reward) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(reward.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            const Text('Confirm Claim'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to spend ${reward.cost} points to claim "${reward.title}"?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your current balance:'),
                  Text(
                    '${currentUser.points} pts',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redeem Reward'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      final res = await ref.read(rewardsControllerProvider.notifier).redeemReward(reward);
      if (!mounted) return;
      if (res.success) {
        TaskCelebrationOverlay.show(
          context,
          points: reward.cost,
          taskTitle: 'Redeemed: ${reward.emoji} ${reward.title}!',
          currentPoints: res.remainingPoints,
        );
      } else {
        showTopSnackBar(context, res.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMember = ref.watch(currentUserProvider);
    final isParent = currentMember?.isParent ?? false;
    final rewardsAsync = ref.watch(householdRewardsStreamProvider);
    final redemptionsAsync = ref.watch(householdRedemptionsStreamProvider);
    final members = ref.watch(householdMembersProvider);

    final rewards = rewardsAsync.value ?? [];
    final redemptions = redemptionsAsync.value ?? [];

    final userPoints = currentMember?.points ?? 0;
    final level = Gamification.levelFor(userPoints);
    final progress = level.progress(userPoints);

    final pendingRedemptions = redemptions.where((r) => r.isPending).toList();
    final myRedemptions = redemptions.where((r) => r.userId == currentMember?.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Points Wallet & Level Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Spendable Points',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          Row(
                            children: [
                              Text(
                                '$userPoints',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFDE68A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'pts',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(level.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'Lvl ${level.number}: ${level.title}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Level Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level Progress',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                  Text(
                    level.nextAt != null
                        ? '$userPoints / ${level.nextAt} pts'
                        : 'Max Level! 👑',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Parent Actions & Pending Approvals Queue
        if (isParent) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rewards Administration',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Custom Reward'),
                onPressed: () => _showCreateRewardDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pending Claims Queue
          if (pendingRedemptions.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pending Claims to Hand Out (${pendingRedemptions.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...pendingRedemptions.map((redemption) {
                    final child = members.cast<FamilyMember?>().firstWhere(
                          (m) => m?.id == redemption.userId,
                          orElse: () => null,
                        );
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Text(redemption.rewardEmoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  redemption.rewardTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Claimed by: ${child?.name ?? "Child"} (-${redemption.cost} pts)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Fulfill'),
                            onPressed: () async {
                              await ref
                                  .read(rewardsControllerProvider.notifier)
                                  .fulfillRedemption(redemption.id);
                              if (context.mounted) {
                                showTopSnackBar(context, '🎉 Reward handed out successfully!');
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],

        // 3. Available Household Rewards Store
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🎁 Rewards Store',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Text(
              '${rewards.length} rewards',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (rewards.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  const Text(
                    'No rewards created yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isParent
                        ? 'Create custom rewards above so children can redeem them with their task points!'
                        : 'Ask your parents to add custom rewards to the store!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 160,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              final canAfford = userPoints >= reward.cost;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: canAfford ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0),
                    width: canAfford ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(reward.emoji, style: const TextStyle(fontSize: 26)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reward.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                if (reward.description != null && reward.description!.isNotEmpty)
                                  Text(
                                    reward.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFD97706)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${reward.cost} pts',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isParent)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showCreateRewardDialog(context, existing: reward);
                                } else if (val == 'delete') {
                                  ref.read(rewardsControllerProvider.notifier).deleteReward(reward.id);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                        ],
                      ),
                      // Redeem Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
                            foregroundColor: canAfford ? Colors.white : Colors.grey.shade500,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: canAfford ? () => _handleRedeem(reward) : null,
                          child: Text(
                            canAfford ? 'Redeem for ${reward.cost} pts' : 'Need ${reward.cost - userPoints} more pts',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // 4. Child's Redemption History
        if (myRedemptions.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'My Claimed Rewards History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          ...myRedemptions.take(4).map((claim) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Text(claim.rewardEmoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      claim.rewardTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: claim.isPending ? Colors.amber.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: claim.isPending ? Colors.amber.shade300 : Colors.green.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          claim.isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                          size: 12,
                          color: claim.isPending ? Colors.amber.shade900 : Colors.green.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          claim.isPending ? 'Pending Handover' : 'Received!',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: claim.isPending ? Colors.amber.shade900 : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
