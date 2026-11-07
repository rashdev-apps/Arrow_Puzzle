import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom animated game-themed illustrations for onboarding.
class OnboardingGraphic extends StatelessWidget {
  final int pageIndex;
  final Color primaryColor;
  final Color accentColor;
  final Color surfaceColor;

  const OnboardingGraphic({
    super.key,
    required this.pageIndex,
    required this.primaryColor,
    required this.accentColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: surfaceColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 36,
            spreadRadius: 8,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: -4,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.1),
          width: 3,
        ),
      ),
      child: ClipOval(
        child: Center(
          child: switch (pageIndex) {
            0 => _WelcomeLogo(primary: primaryColor, accent: accentColor),
            1 => _TapSlideGraphic(primary: primaryColor, accent: accentColor),
            _ => _HeartsGraphic(primary: primaryColor, accent: accentColor),
          },
        ),
      ),
    );
  }
}

/// Dynamic game logo: Interlocking labyrinth snake arrows escaping outwards
class _WelcomeLogo extends StatelessWidget {
  final Color primary;
  final Color accent;

  const _WelcomeLogo({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: CustomPaint(
        painter: _LogoPainter(primary: primary, accent: accent),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color primary;
  final Color accent;

  _LogoPainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Subtle background grid dots
    final dotPaint = Paint()..color = primary.withValues(alpha: 0.12);
    for (int r = -2; r <= 2; r++) {
      for (int c = -2; c <= 2; c++) {
        canvas.drawCircle(center + Offset(c * 24.0, r * 24.0), 2.5, dotPaint);
      }
    }

    final arrowPaint1 = Paint()
      ..color = primary
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final arrowPaint2 = Paint()
      ..color = accent
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Arrow 1: Escaping Up (Accent Blue)
    final path1 = Path()
      ..moveTo(center.dx - 36, center.dy + 36)
      ..lineTo(center.dx - 36, center.dy)
      ..lineTo(center.dx - 12, center.dy)
      ..lineTo(center.dx - 12, center.dy - 44);
    canvas.drawPath(path1, arrowPaint2);
    _drawHead(canvas, Offset(center.dx - 12, center.dy - 56), Offset(center.dx - 12, center.dy - 44), accent, 10);

    // Arrow 2: Interlocking Escaping Right (Primary Brown)
    final path2 = Path()
      ..moveTo(center.dx - 12, center.dy + 36)
      ..lineTo(center.dx + 24, center.dy + 36)
      ..lineTo(center.dx + 24, center.dy - 12)
      ..lineTo(center.dx + 48, center.dy - 12);
    canvas.drawPath(path2, arrowPaint1);
    _drawHead(canvas, Offset(center.dx + 60, center.dy - 12), Offset(center.dx + 48, center.dy - 12), primary, 10);

    // Sparkle badge
    final glow = Paint()
      ..color = accent.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(center.dx - 12, center.dy - 56), 16, glow);
  }

  void _drawHead(Canvas canvas, Offset tip, Offset prev, Color color, double strokeW) {
    final diff = tip - prev;
    final angle = math.atan2(diff.dy, diff.dx);
    final headLen = strokeW * 2.2;
    final headHalfW = strokeW * 1.6;

    final baseCenter = tip - Offset(math.cos(angle) * headLen, math.sin(angle) * headLen);
    final perp = Offset(-math.sin(angle) * headHalfW, math.cos(angle) * headHalfW);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseCenter.dx + perp.dx, baseCenter.dy + perp.dy)
      ..lineTo(baseCenter.dx - perp.dx, baseCenter.dy - perp.dy)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Illustration for "Tap to slide"
class _TapSlideGraphic extends StatelessWidget {
  final Color primary;
  final Color accent;

  const _TapSlideGraphic({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: CustomPaint(
        painter: _TapSlidePainter(primary: primary, accent: accent),
      ),
    );
  }
}

class _TapSlidePainter extends CustomPainter {
  final Color primary;
  final Color accent;

  _TapSlidePainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Path track / motion lines
    final dashPaint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    // Draw motion trail dashed line going right
    for (double x = center.dx - 20; x <= center.dx + 56; x += 10) {
      canvas.drawLine(Offset(x, center.dy - 16), Offset(x + 5, center.dy - 16), dashPaint);
    }

    // Snake arrow that is sliding
    final arrowPaint = Paint()
      ..color = primary
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(center.dx - 48, center.dy + 32)
      ..lineTo(center.dx - 20, center.dy + 32)
      ..lineTo(center.dx - 20, center.dy - 16)
      ..lineTo(center.dx + 30, center.dy - 16);
    canvas.drawPath(path, arrowPaint);

    // Arrow head
    final headTip = Offset(center.dx + 44, center.dy - 16);
    final headPrev = Offset(center.dx + 30, center.dy - 16);
    _drawHead(canvas, headTip, headPrev, primary, 10);

    // Ripple wave under touch
    final ripple = Paint()
      ..color = accent.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(center.dx - 20, center.dy + 32), 22, ripple);
    canvas.drawCircle(Offset(center.dx - 20, center.dy + 32), 12, ripple..color = accent.withValues(alpha: 0.45));

    // Tap finger indicator
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.touch_app_rounded.codePoint),
        style: TextStyle(
          inherit: false,
          color: accent,
          fontSize: 48,
          fontFamily: Icons.touch_app_rounded.fontFamily,
          package: Icons.touch_app_rounded.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(canvas, Offset(center.dx - 34, center.dy + 18));
  }

  void _drawHead(Canvas canvas, Offset tip, Offset prev, Color color, double strokeW) {
    final diff = tip - prev;
    final angle = math.atan2(diff.dy, diff.dx);
    final headLen = strokeW * 2.2;
    final headHalfW = strokeW * 1.6;

    final baseCenter = tip - Offset(math.cos(angle) * headLen, math.sin(angle) * headLen);
    final perp = Offset(-math.sin(angle) * headHalfW, math.cos(angle) * headHalfW);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseCenter.dx + perp.dx, baseCenter.dy + perp.dy)
      ..lineTo(baseCenter.dx - perp.dx, baseCenter.dy - perp.dy)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Illustration for "Clear the path / Hearts"
class _HeartsGraphic extends StatelessWidget {
  final Color primary;
  final Color accent;

  const _HeartsGraphic({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: CustomPaint(
        painter: _HeartsPainter(primary: primary, accent: accent),
      ),
    );
  }
}

class _HeartsPainter extends CustomPainter {
  final Color primary;
  final Color accent;

  _HeartsPainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Circular halo
    final haloPaint = Paint()
      ..color = const Color(0xFFFF5252).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 64, haloPaint);

    // Heart icon
    final heartPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.favorite_rounded.codePoint),
        style: TextStyle(
          inherit: false,
          color: const Color(0xFFFF5252),
          fontSize: 72,
          fontFamily: Icons.favorite_rounded.fontFamily,
          package: Icons.favorite_rounded.fontPackage,
          shadows: [
            BoxShadow(
              color: const Color(0xFFFF5252).withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    heartPainter.paint(canvas, Offset(center.dx - 36, center.dy - 44));

    // Orbiting stars / unlock sparkles
    final starPaint = Paint()..color = const Color(0xFFFFB300);
    _drawStar(canvas, Offset(center.dx - 48, center.dy - 36), 8, starPaint);
    _drawStar(canvas, Offset(center.dx + 48, center.dy - 24), 10, starPaint);
    _drawStar(canvas, Offset(center.dx + 38, center.dy + 38), 6, starPaint);

    // Shield/checkmark ring
    final ring = Paint()
      ..color = primary.withValues(alpha: 0.2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 70, ring);
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final rad = (i % 2 == 0) ? r : r * 0.4;
      final a = (i * math.pi) / 4;
      final x = c.dx + rad * math.cos(a);
      final y = c.dy + rad * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

