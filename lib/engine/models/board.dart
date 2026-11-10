import 'package:equatable/equatable.dart';

import 'arrow.dart';
import 'direction.dart';
import 'grid_cell.dart';

class Board extends Equatable {
  final int rows;
  final int cols;
  final List<bool> mask; // row-major, true = inside playable silhouette
  final List<Arrow> arrows;

  const Board({
    required this.rows,
    required this.cols,
    required this.mask,
    required this.arrows,
  });

  bool isMasked(GridCell cell) =>
      cell.inside(rows, cols) && mask[cell.row * cols + cell.col];

  int get maskCount => mask.where((m) => m).length;
  int get occupiedCount => arrows.fold<int>(0, (sum, a) => sum + a.path.length);
  double get coverage => maskCount == 0 ? 0.0 : occupiedCount / maskCount;

  Arrow? arrowById(String id) {
    for (final a in arrows) {
      if (a.id == id) return a;
    }
    return null;
  }

  Map<GridCell, Arrow> get occupancy {
    final map = <GridCell, Arrow>{};
    for (final a in arrows) {
      for (final cell in a.path) {
        map[cell] = a;
      }
    }
    return map;
  }

  /// Returns all arrows that are currently free to slide out given [remaining] set of arrows
  List<Arrow> freeArrows(Set<String> remaining) {
    final occ = occupancy;
    final free = <Arrow>[];
    for (final a in arrows) {
      if (!remaining.contains(a.id)) continue;
      var canExit = true;
      for (final cell in exitRay(a)) {
        final other = occ[cell];
        if (other != null && other.id != a.id && remaining.contains(other.id)) {
          canExit = false;
          break;
        }
      }
      if (canExit) {
        free.add(a);
      }
    }
    return free;
  }

  /// Ray of cells from immediately past the head to the board boundary
  List<GridCell> exitRay(Arrow arrow) {
    final ray = <GridCell>[];
    var cell = arrow.head.shift(arrow.dir);
    while (cell.inside(rows, cols)) {
      ray.add(cell);
      cell = cell.shift(arrow.dir);
    }
    return ray;
  }

  int cellsToExit(Arrow arrow) {
    var count = 0;
    var cell = arrow.head.shift(arrow.dir);
    while (cell.inside(rows, cols)) {
      count++;
      cell = cell.shift(arrow.dir);
    }
    return count + arrow.length;
  }

  @override
  List<Object?> get props => [rows, cols, mask, arrows];
}

