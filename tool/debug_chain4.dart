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

    // Place arrows in reverse order.
    // An arrow is "open" if its exit ray has no occupied cells.
    // In our reverse construction:
    // Every arrow placed so far (arrows[0..N-1]) MUST eventually be blocked by some later-placed arrow,
    // EXCEPT the very last placed arrow (which will be R1, the only free arrow at the start)!
    // OR, if we allow branching, multiple arrows can be unblocked as long as max_free <= allowedMaxFree.

    while (arrows.length < maxArrows && free.isNotEmpty) {
      // Find all arrows placed so far whose exit ray is currently unblocked
      final unblocked = arrows.where((a) {
        final ray = getExitRay(a, rows, cols);
        return !ray.any((c) => occupied.containsKey(c));
      }).toList();

      // If unblocked is empty, this is the first arrow
      if (unblocked.isEmpty) {
        final first = findAnyArrowWithClearRay(free, occupied, rows, cols, mask, rng, 'a0');
        if (first == null) break;
        arrows.add(first);
        for (final c in first.path) {
          free.remove(c);
          occupied[c] = first.id;
        }
        continue;
      }

      // To keep max_free = 1:
      // If unblocked.length >= 1, we MUST place an arrow that blocks one of the unblocked arrows!
      // In fact, ideally we block unblocked.first or unblocked.last.
      // What if we can block multiple unblocked arrows? Even better!
      // Let's collect all candidate arrows in free cells whose exit ray is clear.
      final candidates = generateCandidateArrows(free, occupied, rows, cols, mask, rng);
      if (candidates.isEmpty) break;

      // Score each candidate:
      // candidates that block unblocked arrows get high score!
      final scored = <(Arrow, int)>[];
      for (final cand in candidates) {
        final candCells = cand.cells;
        var blocksCount = 0;
        for (final u in unblocked) {
          final ray = getExitRay(u, rows, cols);
          if (ray.any((c) => candCells.contains(c))) {
            blocksCount++;
          }
        }
        scored.add((cand, blocksCount));
      }

      // If any candidate blocks >= 1 unblocked arrows, choose from them!
      final blockers = scored.where((s) => s.$2 > 0).toList();
      Arrow chosen;
      if (blockers.isNotEmpty) {
        blockers.sort((a, b) => b.$2.compareTo(a.$2));
        chosen = blockers.first.$1;
      } else {
        // No candidate blocks the unblocked arrow.
        // If we add an arrow that doesn't block unblocked, we increase unblocked count by 1!
        // For early levels (allowedMaxFree = 2), we can allow up to 2 unblocked arrows.
        // But if unblocked.length >= 2, we shouldn't add another unblocked arrow.
        if (unblocked.length >= 2) break;
        chosen = scored.first.$1;
      }

      final arrowWithId = Arrow(id: 'a${arrows.length}', path: chosen.path, dir: chosen.dir);
      arrows.add(arrowWithId);
      for (final c in arrowWithId.path) {
        free.remove(c);
        occupied[c] = arrowWithId.id;
      }
    }

    if (arrows.length >= 15) {
      final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
      final m = DifficultyConfig.evaluate(board);
      print('Seed $seed: arrows=${arrows.length}, maxFree=${m.maxFreeWave}, free0=${m.free0}, avgFree=${m.avgFree}, cov=${(m.coverage*100).toStringAsFixed(1)}%');
    } else {
      print('Seed $seed: stopped early at ${arrows.length}');
    }
  }
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

Arrow? findAnyArrowWithClearRay(Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng, String id) {
  final cands = generateCandidateArrows(free, occupied, rows, cols, mask, rng);
  if (cands.isEmpty) return null;
  return Arrow(id: id, path: cands.first.path, dir: cands.first.dir);
}

List<Arrow> generateCandidateArrows(Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng) {
  final result = <Arrow>[];
  final heads = free.toList()..shuffle(rng);
  for (final head in heads) {
    if (result.length >= 30) break;
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      if (!isRayClear(head, dir, occupied, rows, cols)) continue;
      final targetLen = 3 + rng.nextInt(3);
      final path = walkBackwards(head, dir, targetLen, free, rows, cols, mask, rng);
      if (path.length >= 3) {
        result.add(Arrow(id: '', path: path, dir: dir));
        break;
      }
    }
  }
  return result;
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

