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
  final rng = Random(42);

  final free = <GridCell>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (mask[r * cols + c]) free.add(GridCell(r, c));
    }
  }
  final occupied = <GridCell, String>{};
  final arrows = <Arrow>[];

  // Try placing arrows in reverse order
  // Rn placed first:
  final first = findArrowWithRayClear(free, occupied, rows, cols, mask, rng, 'a0');
  if (first == null) {
    print('No first arrow');
    return;
  }
  arrows.add(first);
  for (final c in first.path) {
    free.remove(c);
    occupied[c] = first.id;
  }

  while (arrows.length < maxArrows && free.isNotEmpty) {
    // We want the new arrow X to:
    // 1. Have a clear exit ray to the edge (no collision with occupied)
    // 2. Block the exit ray of arrows.last (or another arrow in arrows that is not yet blocked)
    // Find unblocked arrows in reverse list
    final unblocked = <Arrow>[];
    for (final a in arrows) {
      final ray = getExitRay(a, rows, cols);
      // Check if ray hits any later-placed arrow
      final isBlocked = ray.any((c) => occupied.containsKey(c));
      if (!isBlocked) {
        unblocked.add(a);
      }
    }

    if (unblocked.isEmpty) break;

    // Pick target to block (prefer unblocked.last)
    final target = unblocked.last;
    final ray = getExitRay(target, rows, cols);
    final rayCells = ray.where((c) => free.contains(c)).toSet();

    // Look for an arrow in free that has >= 1 cell in rayCells AND whose head has a clear ray
    final candidate = findArrowBlockingRay(rayCells, free, occupied, rows, cols, mask, rng, 'a${arrows.length}');
    if (candidate != null) {
      arrows.add(candidate);
      for (final c in candidate.path) {
        free.remove(c);
        occupied[c] = candidate.id;
      }
    } else {
      // If we cannot block unblocked.last, try blocking another unblocked arrow
      var found = false;
      for (final altTarget in unblocked.reversed.skip(1)) {
        final altRay = getExitRay(altTarget, rows, cols).where((c) => free.contains(c)).toSet();
        final altCand = findArrowBlockingRay(altRay, free, occupied, rows, cols, mask, rng, 'a${arrows.length}');
        if (altCand != null) {
          arrows.add(altCand);
          for (final c in altCand.path) {
            free.remove(c);
            occupied[c] = altCand.id;
          }
          found = true;
          break;
        }
      }
      if (!found) {
        // If free cells remain, can we place a decoy arrow whose ray is blocked by unblocked arrows?
        break;
      }
    }
  }

  print('Arrows placed: ${arrows.length}');
  final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
  print('Solvable: ${solver.solvableByGreedy(board)}');
  final m = DifficultyConfig.evaluate(board);
  print('maxFreeWave: ${m.maxFreeWave}, free0: ${m.free0}, avgFree: ${m.avgFree}');
}

List<GridCell> getExitRay(Arrow arrow, int rows, int cols) {
  final ray = <GridCell>[];
  var c = arrow.head.shift(arrow.dir);
  while (c.inside(rows, cols)) {
    ray.add(c);
    c = c.shift(arrow.dir);
  }
  return ray;
}

bool isRayClear(GridCell head, Direction dir, Map<GridCell, String> occupied, int rows, int cols) {
  var c = head.shift(dir);
  while (c.inside(rows, cols)) {
    if (occupied.containsKey(c)) return false;
    c = c.shift(dir);
  }
  return true;
}

Arrow? findArrowWithRayClear(Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng, String id) {
  final heads = free.toList()..shuffle(rng);
  for (final head in heads) {
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      if (!isRayClear(head, dir, occupied, rows, cols)) continue;
      final path = walkBackwards(head, dir, 3 + rng.nextInt(3), free, rows, cols, mask, rng);
      if (path.length >= 3) {
        return Arrow(id: id, path: path, dir: dir);
      }
    }
  }
  return null;
}

Arrow? findArrowBlockingRay(Set<GridCell> rayCells, Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng, String id) {
  // Check candidates starting at various free cells
  final heads = free.toList()..shuffle(rng);
  for (final head in heads) {
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      if (!isRayClear(head, dir, occupied, rows, cols)) continue;
      final path = walkBackwards(head, dir, 3 + rng.nextInt(3), free, rows, cols, mask, rng);
      if (path.length >= 3 && path.any((c) => rayCells.contains(c))) {
        return Arrow(id: id, path: path, dir: dir);
      }
    }
  }
  return null;
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

