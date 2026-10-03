import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gamification.dart';

class TaskCelebrationOverlay extends StatefulWidget {
  final int points;
  final String taskTitle;
  final int currentStreak;
  final int currentPoints;
  final bool isLevelUp;
  final String? newBadge;

  const TaskCelebrationOverlay({
    super.key,
    required this.points,
    required this.taskTitle,
    this.currentStreak = 1,
    this.currentPoints = 0,
    this.isLevelUp = false,
    this.newBadge,
  });

  /// Displays the celebration overlay dialog and auto-dismisses after [duration].
  static Future<void> show(
    BuildContext context, {
    required int points,
    required String taskTitle,
    int currentStreak = 1,
    int currentPoints = 0,
    bool isLevelUp = false,
    String? newBadge,
    Duration duration = const Duration(milliseconds: 2800),
  }) async {
    HapticFeedback.heavyImpact();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Celebration',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return TaskCelebrationOverlay(
          points: points,
          taskTitle: taskTitle,
          currentStreak: currentStreak,
          currentPoints: currentPoints,
          isLevelUp: isLevelUp,
          newBadge: newBadge,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  @override
  State<TaskCelebrationOverlay> createState() => _TaskCelebrationOverlayState();
}

class _TaskCelebrationOverlayState extends State<TaskCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();

    // Generate colorful confetti particles
    final colors = [
      const Color(0xFFF59E0B), // Gold
      const Color(0xFF10B981), // Emerald
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEF4444), // Coral Red
      const Color(0xFF14B8A6), // Teal
    ];

    for (int i = 0; i < 65; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 120.0 + _random.nextDouble() * 220.0;
      _particles.add(
        _ConfettiParticle(
          color: colors[_random.nextInt(colors.length)],
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          size: 6.0 + _random.nextDouble() * 6.0,
          rotationSpeed: (_random.nextDouble() - 0.5) * 8,
          shape: _random.nextBool() ? _ParticleShape.circle : _ParticleShape.ribbon,
        ),
      );
    }

    // Auto-dismiss dialog after 2.6 seconds
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = Gamification.levelFor(widget.currentPoints);
    final progress = level.progress(widget.currentPoints);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Confetti Particle Canvas
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confettiController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ConfettiPainter(
                          particles: _particles,
                          progress: _confettiController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. Center Celebration Card
              Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Icon with Glowing Star / Trophy
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.isLevelUp ? '👑' : (widget.points >= 20 ? '🏆' : '⭐'),
                          style: const TextStyle(fontSize: 38),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      widget.isLevelUp ? 'LEVEL UP!' : 'TASK COMPLETED!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Task Name
                    Text(
                      widget.taskTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Points Reward Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '+${widget.points} Points!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Level & Streak Info Pill
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(level.emoji, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Lvl ${level.number}: ${level.title}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.currentStreak > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🔥', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${widget.currentStreak}d',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (widget.newBadge != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF2F8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF472B6)),
                        ),
                        child: Text(
                          '🎖️ Unlocked: ${widget.newBadge}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFBE185D),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Text(
                      'Tap anywhere to continue',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ParticleShape { circle, ribbon }

class _ConfettiParticle {
  final Color color;
  final Offset velocity;
  final double size;
  final double rotationSpeed;
  final _ParticleShape shape;

  _ConfettiParticle({
    required this.color,
    required this.velocity,
    required this.size,
    required this.rotationSpeed,
    required this.shape,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gravity = progress * progress * 180.0;

    for (final p in particles) {
      final x = center.dx + p.velocity.dx * progress * 0.9;
      final y = center.dy + p.velocity.dy * progress * 0.9 + gravity;
      final alpha = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.rotationSpeed * math.pi);

      if (p.shape == _ParticleShape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
