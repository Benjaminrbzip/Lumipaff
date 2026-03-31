import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../res/colors.dart';

/// A full-screen 3-2-1-GO countdown overlay with 3 concentric colored circles
/// that each unwrap over their associated second, plus pulse waves, rotating
/// dashes, floating particles, and glow effects.
class GameCountdownOverlay extends StatefulWidget {
  final VoidCallback onFinished;

  const GameCountdownOverlay({super.key, required this.onFinished});

  @override
  State<GameCountdownOverlay> createState() => _GameCountdownOverlayState();
}

class _GameCountdownOverlayState extends State<GameCountdownOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _circleController;
  late AnimationController _pulseWaveController;
  late AnimationController _rotateController;
  late AnimationController _particleController;

  late Animation<double> _scaleAnim;

  int _currentCount = 3;
  bool _showGo = false;
  bool _finished = false;

  // Each ring color for 3, 2, 1
  static const List<Color> _ringColors = [
    kCyanColor,            // Ring for "3" (outermost)
    kPrimaryButtonColor,   // Ring for "2" (middle)
    Colors.redAccent,      // Ring for "1" (innermost)
  ];

  // Pre-generated particles
  late final List<_Particle> _particles;
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();

    // Generate particles once
    _particles = List.generate(12, (_) => _Particle(
      angle: _rng.nextDouble() * 2 * math.pi,
      radius: 120.0 + _rng.nextDouble() * 40,
      size: 2.0 + _rng.nextDouble() * 3,
      speed: 0.3 + _rng.nextDouble() * 0.7,
    ));

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 2.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Pulse wave: expands outward on each number change
    _pulseWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Slow continuous rotation for the dashed orbit ring
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Particle floating animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _startCountdown();
  }

  void _startCountdown() {
    _scaleController.forward(from: 0);
    _pulseWaveController.forward(from: 0);
    _circleController.forward(from: 0);

    _circleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;

        if (_currentCount > 1) {
          setState(() => _currentCount--);
          _scaleController.forward(from: 0);
          _pulseWaveController.forward(from: 0);
          _circleController.forward(from: 0);
        } else {
          setState(() => _showGo = true);
          _scaleController.forward(from: 0);
          _pulseWaveController.forward(from: 0);

          Future.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            setState(() => _finished = true);
            widget.onFinished();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _circleController.dispose();
    _pulseWaveController.dispose();
    _rotateController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return const SizedBox.shrink();

    final label = _showGo ? 'GO!' : '$_currentCount';
    final textColor = _showGo
        ? const Color(0xFF4CAF50)
        : _ringColors[3 - _currentCount];

    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleController,
        _circleController,
        _pulseWaveController,
        _rotateController,
        _particleController,
      ]),
      builder: (context, _) {
        return Container(
          color: kPrimaryBackgroundColor.withOpacity(0.94),
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // --- Pulse wave effect ---
                  _buildPulseWave(textColor),
                  // --- Rotating dashed orbit ---
                  _buildRotatingDashes(textColor),
                  // --- Floating particles ---
                  ..._buildParticles(textColor),
                  // --- 3 concentric rings ---
                  if (!_showGo) ..._buildRings(),
                  // --- Number / GO text ---
                  Transform.scale(
                    scale: _scaleAnim.value,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: _showGo ? 72 : 90,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        shadows: [
                          Shadow(
                            color: textColor.withOpacity(0.8),
                            blurRadius: 40,
                          ),
                          Shadow(
                            color: textColor.withOpacity(0.4),
                            blurRadius: 80,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Expanding ring pulse on each number transition.
  Widget _buildPulseWave(Color color) {
    final progress = _pulseWaveController.value;
    final size = 100.0 + progress * 180.0;
    final opacity = (1.0 - progress).clamp(0.0, 0.6);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(opacity),
            width: 2.5 * (1.0 - progress),
          ),
        ),
      ),
    );
  }

  /// Rotating dashed circle around the rings.
  Widget _buildRotatingDashes(Color color) {
    return Transform.rotate(
      angle: _rotateController.value * 2 * math.pi,
      child: SizedBox(
        width: 240,
        height: 240,
        child: CustomPaint(
          painter: _DashedCirclePainter(
            color: color.withOpacity(0.25),
            strokeWidth: 2.0,
            dashCount: 24,
            gapRatio: 0.5,
          ),
        ),
      ),
    );
  }

  /// Floating particles orbiting around the center.
  List<Widget> _buildParticles(Color baseColor) {
    return _particles.map((p) {
      final t = (_particleController.value * p.speed) % 1.0;
      final angle = p.angle + t * 2 * math.pi;
      final wobble = math.sin(t * 4 * math.pi) * 8;
      final r = p.radius + wobble;
      final dx = math.cos(angle) * r;
      final dy = math.sin(angle) * r;
      final opacity = (0.3 + 0.5 * math.sin(t * math.pi)).clamp(0.0, 1.0);

      return Positioned(
        left: 150 + dx - p.size / 2,
        top: 150 + dy - p.size / 2,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withOpacity(opacity),
            boxShadow: [
              BoxShadow(
                color: baseColor.withOpacity(opacity * 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildRings() {
    final List<Widget> rings = [];
    for (int i = 0; i < 3; i++) {
      final ringNumber = 3 - i;
      final color = _ringColors[i];
      final size = 200.0 - (i * 40.0);
      final strokeWidth = 6.0 - (i * 1.0);

      double progress;
      if (_currentCount > ringNumber) {
        progress = 1.0;
      } else if (_currentCount == ringNumber) {
        progress = 1.0 - _circleController.value;
      } else {
        progress = 0.0;
      }

      rings.add(
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              color: color,
              progress: progress,
              strokeWidth: strokeWidth,
            ),
          ),
        ),
      );
    }
    return rings;
  }
}

// --- Data classes & painters ---

class _Particle {
  final double angle;
  final double radius;
  final double size;
  final double speed;
  _Particle({required this.angle, required this.radius, required this.size, required this.speed});
}

/// Draws a circular arc that depletes clockwise with a glow.
class _RingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double strokeWidth;

  _RingPainter({
    required this.color,
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final sweepAngle = 2 * math.pi * progress;
    const startAngle = -math.pi / 2;

    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Draws a dashed circle.
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;
  final double gapRatio;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
    required this.gapRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final totalAngle = 2 * math.pi;
    final dashAngle = totalAngle / dashCount;
    final gap = dashAngle * gapRatio;
    final sweep = dashAngle - gap;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color;
}
