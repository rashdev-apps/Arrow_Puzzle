import 'dart:math';
import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';
import 'package:arrow_puzzle/features/game/logic/generator/shapes.dart';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/logic/solver.dart';

void main() {
  final s = kBuiltinShapes.first;
  final (minArrows, maxArrows) = DifficultyConfig.targetArrowCount(1);
  final targetN = (minArrows + maxArrows) / 2.0;
  final targetCells = targetN * 4.3;
  final scale = sqrt(targetCells / s.cells.length);
  final scaled = s.resized((s.baseRows * scale).round(), (s.baseCols * scale).round());
  final rows = scaled.baseRows;
  final cols = scaled.baseCols;
  final mask = scaled.toMask();

  const solver = Solver();

  for (var seed = 0; seed < 10; seed++) {
    final rng = Random(seed);
    final free = <GridCell>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (mask[r * cols + c]) free.add(GridCell(r, c));
      }
    }
    final occupied = <GridCell, String>{};
    final arrows = <Arrow>[];

    // Allowed boundary exits:
    // If we only allow 1 (or 2) arrows to have exitRay length == 0 (facing the boundary),
    // and all other arrows must face INTO other cells (which later arrows or current arrows occupy)!
    var boundaryExitsAllowed = 2; // For L1, allow 2
    var boundaryExitsUsed = 0;

    while (arrows.length < maxArrows && free.isNotEmpty) {
      final starts = free.toList()..shuffle(rng);
      Arrow? best;

      for (final head in starts) {
        if (best != null) break;
        final dirs = [...DirectionX.orthogonal]..shuffle(rng);
        for (final dir in dirs) {
          // Check ray
          var cell = head.shift(dir);
          var rayLen = 0;
          var clear = true;
          while (cell.inside(rows, cols)) {
            if (occupied.containsKey(cell)) {
              clear = false;
              break;
            }
            rayLen++;
            cell = cell.shift(dir);
          }
          if (!clear) continue;

          // If this arrow exits straight off the board without any ray
          // AND all other placed arrows so far aren't on its path...
          if (rayLen == 0) {
            if (boundaryExitsUsed >= boundaryExitsAllowed) {
              continue; // Do NOT allow another arrow pointing directly out of the board!
            }
          }

          final targetLen = 3 + rng.nextInt(3);
          final path = walkBackwards(head, dir, targetLen, free, rows, cols, mask, rng);
          if (path.length >= 3) {
            best = Arrow(id: 'a${arrows.length}', path: path, dir: dir);
            if (rayLen == 0) boundaryExitsUsed++;
            break;
          }
        }
      }

      if (best == null) break;
      arrows.add(best);
      for (final c in best.path) {
        free.remove(c);
        occupied[c] = best.id;
      }
    }

    if (arrows.length >= 15) {
      final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
      final m = DifficultyConfig.evaluate(board);
      print('Seed $seed: N=${arrows.length}, free0=${m.free0}, maxWave=${m.maxFreeWave}, avgFree=${m.avgFree}, cov=${(m.coverage*100).toStringAsFixed(1)}%');
    } else {
      print('Seed $seed: stopped early at ${arrows.length}');
    }
  }
}

List<GridCell> walkBackwards(GridCell head, Direction forwardDir, int targetLen, Set<GridCell> free, int rows, int cols, List<bool> mask, Random rng) {
  final backwardsDir = forwardDir.opposite;
  final path = <GridCell>[head];
  final claimed = <GridCell>{head};
  var current = head;
  var currentBackDir = backwardsDir;
  while (path.length < targetLen) {
    final candidates = [currentBackDir, turnLeft(currentBackDir), turnRight(currentBackDir)]..shuffle(rng);
    GridCell? next;
    Direction? chosenDir;
    for (final d in candidates) {
      final step = current.shift(d);
      if (step.inside(rows, cols) && mask[step.row * cols + step.col] && free.contains(step) && !claimed.contains(step)) {
        next = step;
        chosenDir = d;
        break;
      }
    }
    if (next == null) break;
    path.add(next);
    claimed.add(next);
    current = next;
    currentBackDir = chosenDir!;
  }
  return path.reversed.toList();
}

Direction turnLeft(Direction d) => switch (d) {
  Direction.up => Direction.left,
  Direction.left => Direction.down,
  Direction.down => Direction.right,
  Direction.right => Direction.up,
};

Direction turnRight(Direction d) => switch (d) {
  Direction.up => Direction.right,
  Direction.right => Direction.down,
  Direction.down => Direction.left,
  Direction.left => Direction.up,
};

