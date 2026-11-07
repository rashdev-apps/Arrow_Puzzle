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
  print('Board: ${rows}x${cols}');

  final rng = Random(42);
  for (var attempt = 0; attempt < 5; attempt++) {
    final free = <GridCell>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (mask[r * cols + c]) free.add(GridCell(r, c));
      }
    }
    final occupied = <GridCell, String>{};
    final chain = <Arrow>[];

    // Pick first arrow
    final firstCandidates = findClearArrows(free, occupied, rows, cols, mask, rng, 'a0', 3, 6);
    if (firstCandidates.isEmpty) {
      print('Attempt $attempt: no first candidates');
      continue;
    }
    final first = firstCandidates.first;
    chain.add(first);
    for (final c in first.path) {
      free.remove(c);
      occupied[c] = first.id;
    }

    while (chain.length < maxArrows && free.isNotEmpty) {
      final prev = chain.last;
      final ray = getExitRay(prev, rows, cols);
      final rayAvailable = ray.where((c) => free.contains(c)).toList();
      if (rayAvailable.isEmpty) {
        print('  Chain stopped at ${chain.length}: rayAvailable empty');
        break;
      }
      rayAvailable.shuffle(rng);
      Arrow? bestCandidate;
      for (final anchor in rayAvailable) {
        final candidates = findArrowsCrossing(anchor, free, occupied, rows, cols, mask, rng, 'a${chain.length}', 3, 7);
        if (candidates.isNotEmpty) {
          bestCandidate = candidates.first;
          break;
        }
      }
      if (bestCandidate == null) {
        print('  Chain stopped at ${chain.length}: no candidate crossing ray');
        break;
      }
      chain.add(bestCandidate);
      for (final c in bestCandidate.path) {
        free.remove(c);
        occupied[c] = bestCandidate.id;
      }
    }
    print('Attempt $attempt finished with chain length ${chain.length}');
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

List<Arrow> findClearArrows(Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng, String id, int minLen, int maxLen) {
  final result = <Arrow>[];
  final heads = free.toList()..shuffle(rng);
  for (final head in heads) {
    if (result.length >= 8) break;
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      if (!isRayClear(head, dir, occupied, rows, cols)) continue;
      final targetLen = minLen + rng.nextInt(maxLen - minLen + 1);
      final path = walkBackwardsFromHead(head, dir, targetLen, free, occupied, rows, cols, mask, rng);
      if (path.length >= minLen) {
        result.add(Arrow(id: id, path: path, dir: dir));
        break;
      }
    }
  }
  return result;
}

List<Arrow> findArrowsCrossing(GridCell anchor, Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng, String id, int minLen, int maxLen) {
  final result = <Arrow>[];
  final dirs = [...DirectionX.orthogonal]..shuffle(rng);
  // Test both anchor as head, and anchor as body cell!
  for (final dir in dirs) {
    // 1. anchor as head
    final head = anchor;
    if (isRayClear(head, dir, occupied, rows, cols)) {
      final targetLen = minLen + rng.nextInt(maxLen - minLen + 1);
      final path = walkBackwardsFromHead(head, dir, targetLen, free, occupied, rows, cols, mask, rng);
      if (path.length >= minLen) {
        result.add(Arrow(id: id, path: path, dir: dir));
        continue;
      }
    }
    // 2. anchor as body cell
    // head must be somewhere in free cells such that anchor is reached in backwards walk
  }
  return result;
}

List<GridCell> walkBackwardsFromHead(GridCell head, Direction forwardDir, int targetLen, Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng) {
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

