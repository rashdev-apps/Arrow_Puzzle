import 'package:equatable/equatable.dart';

import 'arrow.dart';
import 'grid_cell.dart';

/// Immutable board: a silhouette [mask] on a rows x cols grid plus the
/// [arrows] occupying masked cells.
class Board extends Equatable {
  final int rows;
  final int cols;

  /// Row-major boolean mask: `true` = playable cell.
  final List<bool> mask;
  final List<Arrow> arrows;

  const Board({
    required this.rows,
    required this.cols,
    required this.mask,
    required this.arrows,
  });

  bool isMasked(GridCell cell) =>
      cell.inside(rows, cols) && mask[cell.row * cols + cell.col];

  int get maskedCellCount => mask.where((m) => m).length;

  Arrow? arrowById(String id) {
    for (final a in arrows) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Maps every occupied cell to the arrow that owns it.
  Map<GridCell, Arrow> get occupancy {
    final map = <GridCell, Arrow>{};
    for (final arrow in arrows) {
      for (final cell in arrow.path) {
        map[cell] = arrow;
      }
    }
    return map;
  }

  /// Straight ray of grid cells from just past the head to the board edge,
  /// in the arrow's exit direction.
  List<GridCell> exitRay(Arrow arrow) {
    final ray = <GridCell>[];
    var cell = arrow.head.shift(arrow.dir);
    while (cell.inside(rows, cols)) {
      ray.add(cell);
      cell = cell.shift(arrow.dir);
    }
    return ray;
  }

  /// Number of cells an arrow must travel straight to fully leave the grid,
  /// starting from its head cell.
  int cellsToExit(Arrow arrow) => exitRay(arrow).length + 1;

  /// The arrow is free when no *remaining* other arrow occupies any cell of
  /// its exit ray.
  bool isFree(Arrow arrow, Set<String> remainingIds) {
    final occ = occupancy;
    for (final cell in exitRay(arrow)) {
      final blocker = occ[cell];
      if (blocker != null && blocker.id != arrow.id) {
        if (remainingIds.contains(blocker.id)) return false;
      }
    }
    return true;
  }

  List<Arrow> freeArrows(Set<String> remainingIds) => arrows
      .where((a) => remainingIds.contains(a.id) && isFree(a, remainingIds))
      .toList(growable: false);

  @override
  List<Object?> get props => [rows, cols, mask, arrows];
}
