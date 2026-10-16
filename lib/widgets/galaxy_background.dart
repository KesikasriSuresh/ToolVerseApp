import 'dart:math' as math;
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// TOOLVERSE COSMIC GALAXY BACKGROUND (Cursor-Interactive Astra-style Galaxy)
// ---------------------------------------------------------------------------

class ToolVerseGalaxyBackground extends StatefulWidget {
  final Widget child;
  final bool enableMouseReaction;
  final double baseOpacity;

  const ToolVerseGalaxyBackground({
    super.key,
    required this.child,
    this.enableMouseReaction = true,
    this.baseOpacity = 0.85,
  });

  @override
  State<ToolVerseGalaxyBackground> createState() =>
      _ToolVerseGalaxyBackgroundState();
}

class _ToolVerseGalaxyBackgroundState extends State<ToolVerseGalaxyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  Offset _targetNormalized = Offset.zero; // -1.0 to 1.0
  Offset _currentNormalized = Offset.zero;

  // Star collection
  late final List<_GalaxyStar> _stars;
  late final List<_DistantStar> _bgStars;
  late final List<_ConstellationLine> _constellations;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _stars = _generateSpiralStars(count: 360, arms: 3);
    _bgStars = _generateBackgroundStars(count: 140);
    _constellations = _generateConstellations();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  List<_GalaxyStar> _generateSpiralStars({
    required int count,
    required int arms,
  }) {
    final rand = math.Random(42);
    final list = <_GalaxyStar>[];

    final colors = [
      const Color(0xFF00D4FF), // Cyan
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFFFFFFF), // Pure white
      const Color(0xFF67E8F9), // Ice Cyan
      const Color(0xFFC084FC), // Lavender Violet
      const Color(0xFFFFD166), // Gold Star
      const Color(0xFF10F7A0), // Neon Green Toolverse
    ];

    for (int i = 0; i < count; i++) {
      final armIndex = i % arms;
      final armAngleOffset = (2 * math.pi / arms) * armIndex;

      // Distance from center: higher density toward center, tapering outward
      final t = math.pow(rand.nextDouble(), 1.4).toDouble();
      final dist = 30.0 + t * 420.0;

      // Logarithmic spiral angle theta = b * ln(r)
      final spiralAngle = 2.4 * math.log(dist / 20.0) + armAngleOffset;

      // Normal scatter around arm
      final scatterDist = (rand.nextDouble() - 0.5) * (18.0 + dist * 0.18);
      final scatterAngle = spiralAngle + math.pi / 2;

      final x = dist * math.cos(spiralAngle) + scatterDist * math.cos(scatterAngle);
      final y = dist * math.sin(spiralAngle) + scatterDist * math.sin(scatterAngle);

      final size = rand.nextDouble() < 0.85
          ? 0.8 + rand.nextDouble() * 1.8
          : 2.4 + rand.nextDouble() * 2.2; // occasional bright supergiant star

      final colorIndex = rand.nextInt(colors.length);
      final twinkleSpeed = 0.5 + rand.nextDouble() * 2.5;
      final twinklePhase = rand.nextDouble() * 2 * math.pi;
      final depth = 0.2 + rand.nextDouble() * 0.8; // 0.2 to 1.0 (z-depth for 3D parallax)

      list.add(_GalaxyStar(
        baseX: x,
        baseY: y,
        distFromCenter: dist,
        size: size,
        color: colors[colorIndex],
        twinkleSpeed: twinkleSpeed,
        twinklePhase: twinklePhase,
        depth: depth,
        arm: armIndex,
      ));
    }
    return list;
  }

  List<_DistantStar> _generateBackgroundStars({required int count}) {
    final rand = math.Random(1337);
    final list = <_DistantStar>[];
    for (int i = 0; i < count; i++) {
      list.add(_DistantStar(
        relX: rand.nextDouble(),
        relY: rand.nextDouble(),
        size: 0.5 + rand.nextDouble() * 1.3,
        twinkleSpeed: 0.3 + rand.nextDouble() * 1.8,
        twinklePhase: rand.nextDouble() * 2 * math.pi,
        alpha: 0.15 + rand.nextDouble() * 0.55,
      ));
    }
    return list;
  }

  List<_ConstellationLine> _generateConstellations() {
    // Faint cosmic lines connecting select nodes to evoke toolverse sharing network
    return const [
      _ConstellationLine(arm: 0, fromRadius: 90, toRadius: 150),
      _ConstellationLine(arm: 0, fromRadius: 150, toRadius: 230),
      _ConstellationLine(arm: 1, fromRadius: 110, toRadius: 180),
      _ConstellationLine(arm: 1, fromRadius: 180, toRadius: 270),
      _ConstellationLine(arm: 2, fromRadius: 80, toRadius: 160),
      _ConstellationLine(arm: 2, fromRadius: 160, toRadius: 240),
    ];
  }

  void _onPointerMove(PointerEvent event, Size size) {
    if (!widget.enableMouseReaction || size.width <= 0 || size.height <= 0) return;
    final normX = ((event.localPosition.dx / size.width) - 0.5) * 2.0; // -1.0 to 1.0
    final normY = ((event.localPosition.dy / size.height) - 0.5) * 2.0;
    _targetNormalized = Offset(normX.clamp(-1.0, 1.0), normY.clamp(-1.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) => _onPointerMove(e, size),
          onPointerMove: (e) => _onPointerMove(e, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Deep cosmic background painter
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, _) {
                    // Smoothly interpolate towards cursor target for fluid inertia
                    _currentNormalized = Offset(
                      _currentNormalized.dx + (_targetNormalized.dx - _currentNormalized.dx) * 0.08,
                      _currentNormalized.dy + (_targetNormalized.dy - _currentNormalized.dy) * 0.08,
                    );

                    return CustomPaint(
                      size: size,
                      painter: _GalaxyPainter(
                        progress: _animCtrl.value,
                        cursorOffset: _currentNormalized,
                        stars: _stars,
                        bgStars: _bgStars,
                        constellations: _constellations,
                        opacity: widget.baseOpacity,
                      ),
                    );
                  },
                ),
              ),
              // App content
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// GALAXY CUSTOM PAINTER
// ---------------------------------------------------------------------------

class _GalaxyPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (ambient continuous rotation)
  final Offset cursorOffset; // -1.0 to 1.0 (cursor parallax position)
  final List<_GalaxyStar> stars;
  final List<_DistantStar> bgStars;
  final List<_ConstellationLine> constellations;
  final double opacity;

  _GalaxyPainter({
    required this.progress,
    required this.cursorOffset,
    required this.stars,
    required this.bgStars,
    required this.constellations,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width * 0.5, size.height * 0.48);

    // 1. Deep Midnight Base Background Fill
    final bgPaint = Paint()..color = const Color(0xFF080B14);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Parallax Camera Shift based on cursor
    // The galaxy core shifts dynamically, and rotates in 3D tilt
    final parallaxX = cursorOffset.dx * 55.0;
    final parallaxY = cursorOffset.dy * 45.0;
    final galaxyCenter = center + Offset(parallaxX, parallaxY);

    // 3. Ambient Distant Stars (Twinkling space field)
    final bgStarPaint = Paint()..style = PaintingStyle.fill;
    for (final bs in bgStars) {
      final twinkle = 0.5 + 0.5 * math.sin(progress * 2 * math.pi * bs.twinkleSpeed + bs.twinklePhase);
      final alpha = (bs.alpha * twinkle * opacity).clamp(0.0, 1.0);
      bgStarPaint.color = Colors.white.withValues(alpha: alpha);

      // Micro parallax on background field
      final starPos = Offset(
        (bs.relX * size.width + parallaxX * 0.15) % size.width,
        (bs.relY * size.height + parallaxY * 0.15) % size.height,
      );
      canvas.drawCircle(starPos, bs.size, bgStarPaint);
    }

    // 4. Cosmic Glowing Nebulae behind Galaxy Core
    _drawNebulae(canvas, galaxyCenter, size);

    // 5. Ambient Rotation Angle + Cursor Tilt
    final rotationAngle = progress * 2 * math.pi;
    final cursorTiltX = cursorOffset.dx * 0.35; // perspective stretch/tilt
    final cursorTiltY = cursorOffset.dy * 0.25;

    // 6. Constellation Links (Ethereal toolverse node connections)
    _drawConstellationLinks(canvas, galaxyCenter, rotationAngle, cursorTiltX, cursorTiltY);

    // 7. Render Spiral Galaxy Stars
    final starPaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    for (final s in stars) {
      // 3D Rotation of base (x, y) coordinates
      final cosRot = math.cos(rotationAngle);
      final sinRot = math.sin(rotationAngle);

      // Rotated around galaxy center
      final rx = s.baseX * cosRot - s.baseY * sinRot;
      final ry = s.baseX * sinRot + s.baseY * cosRot;

      // 3D perspective distortion influenced by cursor tilt
      final tiltFactorY = 0.68 + cursorTiltY * 0.22; // perspective oval flattening
      final finalX = galaxyCenter.dx + rx + (rx * cursorTiltX * 0.15) + (parallaxX * s.depth);
      final finalY = galaxyCenter.dy + (ry * tiltFactorY) + (parallaxY * s.depth);

      // Interactive Cursor Proximity Gravitational Glow
      final distToCursor = math.sqrt(
        math.pow(finalX - (center.dx + cursorOffset.dx * size.width * 0.5), 2) +
        math.pow(finalY - (center.dy + cursorOffset.dy * size.height * 0.5), 2),
      );
      final cursorProximity = (1.0 - (distToCursor / 220.0)).clamp(0.0, 1.0);

      // Twinkle & Brightness
      final twinkle = 0.55 + 0.45 * math.sin(progress * 2 * math.pi * s.twinkleSpeed + s.twinklePhase);
      final baseAlpha = ((0.35 + 0.65 * twinkle) * opacity).clamp(0.0, 1.0);
      final boostedAlpha = math.min(1.0, baseAlpha + cursorProximity * 0.4);

      // Draw soft star glow halo for larger stars
      if (s.size > 1.8 || cursorProximity > 0.4) {
        glowPaint.color = s.color.withValues(alpha: boostedAlpha * 0.28);
        canvas.drawCircle(
          Offset(finalX, finalY),
          s.size * (2.4 + cursorProximity * 1.5),
          glowPaint,
        );
      }

      // Draw core star particle
      starPaint.color = s.color.withValues(alpha: boostedAlpha);
      canvas.drawCircle(
        Offset(finalX, finalY),
        s.size * (1.0 + cursorProximity * 0.3),
        starPaint,
      );
    }

    // 8. Radiant Galactic Core (Bright pulsing heart of ToolVerse)
    _drawGalacticCore(canvas, galaxyCenter);

    // 9. Interactive Cursor Cosmic Aura
    _drawCursorCosmicAura(canvas, center, size);
  }

  void _drawNebulae(Canvas canvas, Offset center, Size size) {
    final maxRadius = math.min(size.width, size.height) * 0.55;

    // Cyan Nebula Cloud
    final cyanPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00D4FF).withValues(alpha: 0.12 * opacity),
          const Color(0xFF00D4FF).withValues(alpha: 0.04 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.85));
    canvas.drawCircle(center, maxRadius * 0.85, cyanPaint);

    // Violet Nebula Cloud (offset slightly for cosmic depth)
    final violetOffset = center + Offset(-30.0 + cursorOffset.dx * 20, 20.0 + cursorOffset.dy * 15);
    final violetPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.14 * opacity),
          const Color(0xFF8B5CF6).withValues(alpha: 0.05 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: violetOffset, radius: maxRadius * 0.95));
    canvas.drawCircle(violetOffset, maxRadius * 0.95, violetPaint);
  }

  void _drawConstellationLinks(
    Canvas canvas,
    Offset galaxyCenter,
    double rotationAngle,
    double cursorTiltX,
    double cursorTiltY,
  ) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.12 * opacity);

    final tiltFactorY = 0.68 + cursorTiltY * 0.22;

    for (final c in constellations) {
      final theta1 = rotationAngle + (c.arm * 2 * math.pi / 3) + 2.4 * math.log(c.fromRadius / 20.0);
      final theta2 = rotationAngle + (c.arm * 2 * math.pi / 3) + 2.4 * math.log(c.toRadius / 20.0);

      final p1 = Offset(
        galaxyCenter.dx + c.fromRadius * math.cos(theta1),
        galaxyCenter.dy + (c.fromRadius * math.sin(theta1) * tiltFactorY),
      );
      final p2 = Offset(
        galaxyCenter.dx + c.toRadius * math.cos(theta2),
        galaxyCenter.dy + (c.toRadius * math.sin(theta2) * tiltFactorY),
      );

      canvas.drawLine(p1, p2, linePaint);
    }
  }

  void _drawGalacticCore(Canvas canvas, Offset center) {
    // Multi-layer luminous core
    // Layer 1: Wide warm white-cyan halo
    final coreHalo = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.7 * opacity),
          const Color(0xFF00D4FF).withValues(alpha: 0.45 * opacity),
          const Color(0xFF8B5CF6).withValues(alpha: 0.18 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 55));
    canvas.drawCircle(center, 55, coreHalo);

    // Layer 2: Ultra-bright stellar nucleus
    final nucleus = Paint()
      ..color = Colors.white.withValues(alpha: 0.95 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 9, nucleus);

    // Sharp center point
    final sharpCenter = Paint()..color = Colors.white;
    canvas.drawCircle(center, 3.5, sharpCenter);
  }

  void _drawCursorCosmicAura(Canvas canvas, Offset center, Size size) {
    // Subtle gravitational dust glow trailing directly under the user's cursor
    final cursorScreenPos = Offset(
      center.dx + cursorOffset.dx * size.width * 0.5,
      center.dy + cursorOffset.dy * size.height * 0.5,
    );

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00D4FF).withValues(alpha: 0.15 * opacity),
          const Color(0xFF8B5CF6).withValues(alpha: 0.05 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: cursorScreenPos, radius: 110));

    canvas.drawCircle(cursorScreenPos, 110, auraPaint);
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cursorOffset != cursorOffset ||
        oldDelegate.opacity != opacity;
  }
}

// ---------------------------------------------------------------------------
// DATA CLASSES
// ---------------------------------------------------------------------------

class _GalaxyStar {
  final double baseX;
  final double baseY;
  final double distFromCenter;
  final double size;
  final Color color;
  final double twinkleSpeed;
  final double twinklePhase;
  final double depth;
  final int arm;

  _GalaxyStar({
    required this.baseX,
    required this.baseY,
    required this.distFromCenter,
    required this.size,
    required this.color,
    required this.twinkleSpeed,
    required this.twinklePhase,
    required this.depth,
    required this.arm,
  });
}

class _DistantStar {
  final double relX;
  final double relY;
  final double size;
  final double twinkleSpeed;
  final double twinklePhase;
  final double alpha;

  _DistantStar({
    required this.relX,
    required this.relY,
    required this.size,
    required this.twinkleSpeed,
    required this.twinklePhase,
    required this.alpha,
  });
}

class _ConstellationLine {
  final int arm;
  final double fromRadius;
  final double toRadius;

  const _ConstellationLine({
    required this.arm,
    required this.fromRadius,
    required this.toRadius,
  });
}
