import 'package:flutter/material.dart';
import '../../domain/models/task_item.dart';

/// Animált érme overlay widget – a jóváhagyásra váró (pending_approval) feladatokat
/// jelzi a 2D alaprajzon, az érintett szoba centroid pozíciójára vetítve.
///
/// Két szimultán animáció:
/// 1. [ScaleTransition]    – lüktető méretváltozás (0.85 ↔ 1.15), loopolt
/// 2. [AnimationController] forgás hatás – glint/shimmer effektus
class AnimatedCoin extends StatefulWidget {
  final TaskItem task;
  final Offset screenPosition; // A szoba centroidjának képernyő-koordinátája
  final VoidCallback? onTap;

  const AnimatedCoin({
    super.key,
    required this.task,
    required this.screenPosition,
    this.onTap,
  });

  @override
  State<AnimatedCoin> createState() => _AnimatedCoinState();
}

class _AnimatedCoinState extends State<AnimatedCoin>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _glintController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glintAnimation;

  static const double _coinSize = 44.0;

  @override
  void initState() {
    super.initState();

    // 1. Lüktető méret-animáció (1.2s, repeat+reverse)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Shimmer / glint forgás hatás (2.5s, folyamatos repeat)
    _glintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _glintAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glintController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // A widget közepét a centroidra igazítjuk
      left: widget.screenPosition.dx - _coinSize / 2,
      top: widget.screenPosition.dy - _coinSize / 2,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedBuilder(
            animation: _glintAnimation,
            builder: (context, child) {
              return _CoinPainterWidget(
                glintProgress: _glintAnimation.value,
                task: widget.task,
                size: _coinSize,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COIN PAINTER WIDGET (CustomPaint alapú)
// ─────────────────────────────────────────────────────────────────────────────

class _CoinPainterWidget extends StatelessWidget {
  final double glintProgress;
  final TaskItem task;
  final double size;

  const _CoinPainterWidget({
    required this.glintProgress,
    required this.task,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Kör alap – arany gradienssel
          CustomPaint(
            size: Size(size, size),
            painter: _CoinBasePainter(glintProgress: glintProgress),
          ),
          // Érme ikon
          const Icon(
            Icons.monetization_on,
            color: Colors.white,
            size: 22,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
          // Külső zöld pulsáló gyűrű (pending state jelzés)
          CustomPaint(
            size: Size(size, size),
            painter: _CoinRingPainter(),
          ),
        ],
      ),
    );
  }
}

class _CoinBasePainter extends CustomPainter {
  final double glintProgress;

  _CoinBasePainter({required this.glintProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Árnyék
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(0, 3), radius * 0.9, shadowPaint);

    // 2. Arany gradiens alap
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: const [
          Color(0xFFFFF176), // Világos arany
          Color(0xFFFFB300), // Arany
          Color(0xFFFF8F00), // Sötét arany
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, gradientPaint);

    // 3. Shimmer/glint fény-effektus (mozgó fényfolt)
    final glintX = -radius + (glintProgress * size.width * 2.5);
    final glintPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH(glintX, 0, radius * 0.8, size.height),
      );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawRect(
      Rect.fromLTWH(glintX, 0, radius * 0.8, size.height),
      glintPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoinBasePainter oldDelegate) =>
      oldDelegate.glintProgress != glintProgress;
}

class _CoinRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = const Color(0xFF00897B).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, radius - 1.5, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
