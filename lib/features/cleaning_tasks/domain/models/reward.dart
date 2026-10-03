/// A household-defined reward that children can redeem with their points.
class Reward {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final String emoji;
  final int cost;

  /// `null` means unlimited.
  final int? stock;
  final bool isActive;
  final DateTime createdAt;

  const Reward({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    required this.emoji,
    required this.cost,
    this.stock,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isSoldOut => stock != null && stock! <= 0;

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id']?.toString() ?? '',
      householdId: json['household_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      emoji: json['emoji'] as String? ?? '🎁',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

enum RedemptionStatus { pending, fulfilled }

/// A purchase of a [Reward] by a child. Stays `pending` until an adult hands it over.
class RewardRedemption {
  final String id;
  final String? rewardId;
  final String userId;
  final String rewardTitle;
  final String rewardEmoji;
  final int cost;
  final RedemptionStatus status;
  final DateTime createdAt;
  final DateTime? fulfilledAt;

  const RewardRedemption({
    required this.id,
    this.rewardId,
    required this.userId,
    required this.rewardTitle,
    required this.rewardEmoji,
    required this.cost,
    required this.status,
    required this.createdAt,
    this.fulfilledAt,
  });

  bool get isPending => status == RedemptionStatus.pending;

  factory RewardRedemption.fromJson(Map<String, dynamic> json) {
    return RewardRedemption(
      id: json['id']?.toString() ?? '',
      rewardId: json['reward_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      rewardTitle: json['reward_title'] as String? ?? '',
      rewardEmoji: json['reward_emoji'] as String? ?? '🎁',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      status: json['status'] == 'fulfilled' ? RedemptionStatus.fulfilled : RedemptionStatus.pending,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      fulfilledAt: DateTime.tryParse(json['fulfilled_at'] as String? ?? ''),
    );
  }
}
