import 'dart:math' as math;
import 'dart:ui';

import '../domain/arrow.dart';

/// Geometry helpers to map between grid cells and board pixel space, plus
/// tolerant hit-testing of arrow polylines.
class BoardGeometry {
  /// Side length of one cell in board pixel space.
  final double cellSize;

  const BoardGeometry(this.cellSize);

  Offset cellCenter(int row, int col) =>
      Offset((col + 0.5) * cellSize, (row + 0.5) * cellSize);

  Offset get offset => Offset.zero;

  /// Point-to-segment distance.
  static double segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - projection).distance;
  }
}

/// Finds which arrow (if any) was tapped, with a configurable tolerance so
/// thin lines stay tappable on dense boards.
class HitTester {
  final double tolerance;

  const HitTester({this.tolerance = 14});

  /// [point] is in board pixel space (cellSize-scaled). Returns the arrow
  /// whose polyline is closest to [point] within [tolerance]; on ties the
  /// shortest arrow wins (small arrows sit inside big ones).
  Arrow? hit(
    List<Arrow> arrows,
    Offset point,
    double cellSize,
  ) {
    final geo = BoardGeometry(cellSize);
    Arrow? best;
    var bestDist = tolerance;
    for (final arrow in arrows) {
      for (var i = 0; i < arrow.path.length - 1; i++) {
        final a = arrow.path[i];
        final b = arrow.path[i + 1];
        final d = BoardGeometry.segmentDistance(
          point,
          geo.cellCenter(a.row, a.col),
          geo.cellCenter(b.row, b.col),
        );
        // Slightly favour taps near the arrowhead.
        final isHeadSegment = i == arrow.path.length - 2;
        final effective = isHeadSegment ? d * 0.8 : d;
        if (effective < bestDist ||
            (effective == bestDist && best != null && arrow.length < best.length)) {
          bestDist = effective;
          best = arrow;
        }
      }
      // Single-cell arrows: test distance to their only cell centre.
      if (arrow.path.length == 1) {
        final c = arrow.path.first;
        final d = (point - geo.cellCenter(c.row, c.col)).distance;
        if (d < bestDist) {
          bestDist = d;
          best = arrow;
        }
      }
    }
    return best;
  }

  /// Convenience: tap position from a cell.
  static Offset tapInCell(double cellSize, int row, int col,
      {double dx = 0.5, double dy = 0.5}) =>
      Offset((col + dx) * cellSize, (row + dy) * cellSize);

  static double hypot(double a, double b) => math.sqrt(a * a + b * b);
}
