import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/arrow.dart';
import '../domain/board.dart';
import '../domain/direction.dart';
import '../domain/grid_cell.dart';

/// Animation applied to a single arrow, driven by the widget layer through
/// [progress] in [0,1].
class ArrowAnimation {
  final Arrow arrow;

  /// Exit direction for slides (bump wiggles perpendicular to it).
  final Direction dir;

  /// Number of cells to travel to fully exit the grid.
  final int exitCells;

  /// 0..1 progress of the animation.
  final double progress;

  final ArrowAnimationType type;

  const ArrowAnimation({
    required this.arrow,
    required this.dir,
    required this.exitCells,
    required this.progress,
    required this.type,
  });

  /// Eased slide offset in cells (ease-in: accelerating out).
  double get easedCells {
    final t = progress.clamp(0.0, 1.0);
    final eased = t * t * (3 - 2 * t); // smoothstep
    return switch (type) {
      ArrowAnimationType.slideOut => eased * exitCells,
      ArrowAnimationType.slideIn => (1 - eased) * exitCells,
      ArrowAnimationType.bump => 0,
    };
  }

  /// Perpendicular wiggle offset for the blocked bump (in cells).
  double get bumpOffset {
    if (type != ArrowAnimationType.bump) return 0;
    final t = progress.clamp(0.0, 1.0);
    return math.sin(t * math.pi * 6) * 0.12 * (1 - t);
  }

  double get opacity => switch (type) {
        ArrowAnimationType.slideOut => progress < 0.75 ? 1.0 : 1 - (progress - 0.75) / 0.25,
        ArrowAnimationType.slideIn => progress < 0.25 ? (progress) / 0.25 : 1.0,
        ArrowAnimationType.bump => 1.0,
      };
}

enum ArrowAnimationType { slideOut, slideIn, bump }

/// Single-canvas painter for the whole board. Static arrow paths are cached
/// as [ui.Path] objects; only the (single) animating arrow is recomputed per
/// frame. Repaints are driven by the [repaint] Listenable supplied by the
/// widget layer's AnimationController.
class BoardPainter extends CustomPainter {
  final Board board;
  final Set<String> remainingIds;
  final double cellSize;

  final AppThemeData theme;
  final bool colorblind;

  final String? hintArrowId;
  final String? blockedArrowId;
  final List<GridCell> blockedRay;
  final ArrowAnimation? animation;

  final Map<String, (ui.Path, Offset, Offset)> _geometryCache = {};

  BoardPainter({
    required this.board,
    required this.remainingIds,
    required this.cellSize,
    required this.theme,
    required Listenable repaint,
    this.colorblind = false,
    this.hintArrowId,
    this.blockedArrowId,
    this.blockedRay = const [],
    this.animation,
  }) : super(repaint: repaint);

  Color get _arrowColor => theme.arrowColor;
  Color get _blockedColor =>
      colorblind ? ColorblindHighlights.blocked : theme.arrowBlocked;
  Color get _hintColor => colorblind ? ColorblindHighlights.hint : theme.arrowHint;

  // Stroke width ratio calibrated to reference: bold, crisp, rounded
  double get strokeWidth => (cellSize * 0.18).clamp(3.0, 10.0);

  Offset _center(GridCell c) =>
      Offset((c.col + 0.5) * cellSize, (c.row + 0.5) * cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle mask silhouette so the shape reads on the background.
    _paintMask(canvas);

    // Blocked ray highlight (under arrows).
    if (blockedRay.isNotEmpty && blockedArrowId != null) {
      _paintBlockedRay(canvas);
    }

    for (final arrow in board.arrows) {
      if (!remainingIds.contains(arrow.id)) continue;
      _paintArrow(canvas, arrow);
    }
  }

  void _paintMask(Canvas canvas) {
    // Crisp clean canvas matching reference screenshot:
    // Pure white canvas with no noisy background boxes or heavy dots so the maze lines pop sharply.
  }

  void _paintBlockedRay(Canvas canvas) {
    final arrow = board.arrowById(blockedArrowId!);
    if (arrow == null) return;
    final paint = Paint()
      ..color = _blockedColor.withValues(alpha: 0.35)
      ..strokeWidth = strokeWidth * 1.6
      ..strokeCap = StrokeCap.round;
    final start = _center(arrow.head);
    final endCell = blockedRay.isEmpty ? arrow.head : blockedRay.last;
    final end = _center(endCell) +
        Offset(arrow.dir.dc * cellSize * 0.4, arrow.dir.dr * cellSize * 0.4);
    canvas.drawLine(start, end, paint);
  }

  void _paintArrow(Canvas canvas, Arrow arrow) {
    final anim = animation?.arrow.id == arrow.id ? animation : null;
    final isBlocked = blockedArrowId == arrow.id;
    final isHint = hintArrowId == arrow.id;

    final color = isBlocked ? _blockedColor : _arrowColor;

    canvas.save();

    // If animating a bump, apply perpendicular wiggle
    if (anim != null && anim.type == ArrowAnimationType.bump) {
      final d = anim.dir;
      final perp = anim.bumpOffset * cellSize;
      canvas.translate(-d.dr * perp, d.dc * perp);
    }

    final basePaint = Paint()
      ..color = color.withValues(alpha: anim?.opacity ?? 1.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final (bodyPath, tip, prev) = _computeArrowGeometry(arrow, anim);

    // Hint glow beneath.
    if (isHint) {
      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = _hintColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawPath(bodyPath, basePaint);

    final headPaint = Paint()
      ..color = color.withValues(alpha: anim?.opacity ?? 1.0)
      ..style = PaintingStyle.fill;
    drawArrowHead(canvas, tip, prev, headPaint, strokeWidth);

    // Small accent ring on the head for the hint.
    if (isHint) {
      canvas.drawCircle(
        tip,
        cellSize * 0.34,
        Paint()
          ..color = _hintColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  /// Computes the snake-like path of the arrow body ending at the triangle base,
  /// the arrowhead tip [Offset], and the previous point along the heading vector [Offset].
  (ui.Path, Offset, Offset) _computeArrowGeometry(Arrow arrow, ArrowAnimation? anim) {
    final headLen = cellSize * 0.32;

    if (anim == null || anim.type == ArrowAnimationType.bump) {
      return _geometryCache.putIfAbsent(arrow.id, () {
        final originalNodes = arrow.path.map(_center).toList();
        final tip = originalNodes.last;
        final prev = originalNodes.length >= 2
            ? originalNodes[originalNodes.length - 2]
            : tip - const Offset(1, 0);

        final diff = tip - prev;
        final angle = math.atan2(diff.dy, diff.dx);
        final unit = Offset(math.cos(angle), math.sin(angle));
        final baseCenter = tip - unit * headLen;

        final path = ui.Path();
        path.moveTo(originalNodes.first.dx, originalNodes.first.dy);
        for (var i = 1; i < originalNodes.length - 1; i++) {
          path.lineTo(originalNodes[i].dx, originalNodes[i].dy);
        }
        path.lineTo(baseCenter.dx, baseCenter.dy);

        return (path, tip, prev);
      });
    }

    final slideDist = anim.easedCells * cellSize;
    final originalNodes = arrow.path.map(_center).toList();

    // Determine exit direction from the last segment of the arrow path
    final lastSegDiff = originalNodes.last - (originalNodes.length >= 2 ? originalNodes[originalNodes.length - 2] : originalNodes.last);
    final exitAngle = math.atan2(lastSegDiff.dy, lastSegDiff.dx);
    final exitUnit = Offset(math.cos(exitAngle), math.sin(exitAngle));

    final totalExitDist = (anim.exitCells + 2) * cellSize;
    final extendedHeadNode = originalNodes.last + exitUnit * totalExitDist;

    final fullTrack = [...originalNodes, extendedHeadNode];

    // Compute cumulative segment distances along fullTrack
    final segLengths = <double>[];
    for (var i = 0; i < fullTrack.length - 1; i++) {
      final len = (fullTrack[i + 1] - fullTrack[i]).distance;
      segLengths.add(len);
    }

    final originalBodyLength = (arrow.path.length - 1) * cellSize;

    final tailDist = slideDist;
    final tipDist = slideDist + originalBodyLength;
    final baseDist = (tipDist - headLen).clamp(tailDist, tipDist);

    Offset pointAtDist(double dist) {
      if (dist <= 0) return fullTrack.first;
      var accum = 0.0;
      for (var i = 0; i < segLengths.length; i++) {
        final segLen = segLengths[i];
        if (dist <= accum + segLen) {
          final t = (dist - accum) / segLen;
          return Offset.lerp(fullTrack[i], fullTrack[i + 1], t)!;
        }
        accum += segLen;
      }
      return fullTrack.last;
    }

    // Dynamic path up to baseDist so line stroke ends at triangle base
    final dynamicPath = ui.Path();
    final tailPoint = pointAtDist(tailDist);
    dynamicPath.moveTo(tailPoint.dx, tailPoint.dy);

    var distAccum = 0.0;
    for (var i = 0; i < segLengths.length; i++) {
      distAccum += segLengths[i];
      if (distAccum > tailDist && distAccum < baseDist) {
        final vertex = fullTrack[i + 1];
        dynamicPath.lineTo(vertex.dx, vertex.dy);
      }
    }

    final basePoint = pointAtDist(baseDist);
    dynamicPath.lineTo(basePoint.dx, basePoint.dy);

    final tipPoint = pointAtDist(tipDist);
    // Point immediately behind tip along the track to determine heading
    final prevPoint = pointAtDist(math.max(0.0, tipDist - 1.0));

    return (dynamicPath, tipPoint, prevPoint);
  }

  /// Single standardized function to draw arrowheads across all render states.
  /// Angle = atan2 of the LAST segment only;
  /// Triangle length ≈ 3.0×stroke, width ≈ 3.2×stroke, centered on axis, base perpendicular to line;
  /// Stroke ends exactly at triangle base.
  static void drawArrowHead(
    Canvas canvas,
    Offset tip,
    Offset prev,
    Paint paint,
    double strokeW,
  ) {
    final diff = tip - prev;
    final angle = math.atan2(diff.dy, diff.dx);

    final headLen = strokeW * 3.0;
    final halfW = (strokeW * 3.2) / 2.0;

    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    final baseCenter = tip - Offset(cosA * headLen, sinA * headLen);
    final perp = Offset(-sinA * halfW, cosA * halfW);

    final leftBase = baseCenter + perp;
    final rightBase = baseCenter - perp;

    final path = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(leftBase.dx, leftBase.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) =>
      old.remainingIds != remainingIds ||
      old.cellSize != cellSize ||
      old.hintArrowId != hintArrowId ||
      old.blockedArrowId != blockedArrowId ||
      old.animation != animation ||
      old.theme != theme ||
      old.colorblind != colorblind;
}
