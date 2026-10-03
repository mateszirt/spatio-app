import 'dart:math' as math;

/// A progression level derived from lifetime points (spending points never lowers it).
class GamificationLevel {
  final int number;
  final String title;
  final String emoji;
  final int minPoints;

  /// Lifetime points required for the next level, or `null` at max level.
  final int? nextAt;

  const GamificationLevel({
    required this.number,
    required this.title,
    required this.emoji,
    required this.minPoints,
    this.nextAt,
  });

  bool get isMax => nextAt == null;

  /// Progress inside the current level, 0.0 – 1.0.
  double progress(int lifetimePoints) {
    if (nextAt == null) return 1.0;
    final span = nextAt! - minPoints;
    if (span <= 0) return 1.0;
    return ((lifetimePoints - minPoints) / span).clamp(0.0, 1.0);
  }
}

class Badge {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final bool unlocked;

  const Badge({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.unlocked,
  });
}

/// Pure gamification rules: levels and badges are derived, so no extra DB state is needed.
class Gamification {
  Gamification._();

  static const List<({int min, String title, String emoji})> _levels = [
    (min: 0, title: 'Fresh Sprout', emoji: '🌱'),
    (min: 50, title: 'Tidy Helper', emoji: '🧽'),
    (min: 150, title: 'Sparkle Scout', emoji: '✨'),
    (min: 300, title: 'Clean Hero', emoji: '🦸'),
    (min: 600, title: 'Dust Slayer', emoji: '⚔️'),
    (min: 1000, title: 'Home Champion', emoji: '🏆'),
    (min: 1600, title: 'Living Legend', emoji: '👑'),
  ];

  static GamificationLevel levelFor(int lifetimePoints) {
    final pts = math.max(0, lifetimePoints);
    var index = 0;
    for (var i = 0; i < _levels.length; i++) {
      if (pts >= _levels[i].min) index = i;
    }
    final current = _levels[index];
    final next = index + 1 < _levels.length ? _levels[index + 1].min : null;
    return GamificationLevel(
      number: index + 1,
      title: current.title,
      emoji: current.emoji,
      minPoints: current.min,
      nextAt: next,
    );
  }

  static List<Badge> badgesFor({
    required int lifetimePoints,
    required int streakDays,
    required int tasksCompleted,
  }) {
    return [
      Badge(
        id: 'first_task',
        name: 'First Step',
        emoji: '👟',
        description: 'Complete your first task',
        unlocked: tasksCompleted >= 1,
      ),
      Badge(
        id: 'ten_tasks',
        name: 'Getting Busy',
        emoji: '🧹',
        description: 'Complete 10 tasks',
        unlocked: tasksCompleted >= 10,
      ),
      Badge(
        id: 'fifty_tasks',
        name: 'Task Master',
        emoji: '🎖️',
        description: 'Complete 50 tasks',
        unlocked: tasksCompleted >= 50,
      ),
      Badge(
        id: 'streak_3',
        name: 'On Fire',
        emoji: '🔥',
        description: 'Keep a 3-day streak',
        unlocked: streakDays >= 3,
      ),
      Badge(
        id: 'streak_7',
        name: 'Week Warrior',
        emoji: '🛡️',
        description: 'Keep a 7-day streak',
        unlocked: streakDays >= 7,
      ),
      Badge(
        id: 'points_100',
        name: 'Point Collector',
        emoji: '💰',
        description: 'Earn 100 points in total',
        unlocked: lifetimePoints >= 100,
      ),
      Badge(
        id: 'points_500',
        name: 'Treasure Hunter',
        emoji: '💎',
        description: 'Earn 500 points in total',
        unlocked: lifetimePoints >= 500,
      ),
    ];
  }

  /// Whether the streak is still alive today (it is shown, but a lapsed streak resets on next completion).
  static String streakLabel(int days) => days == 1 ? '1-day streak' : '$days-day streak';
}
