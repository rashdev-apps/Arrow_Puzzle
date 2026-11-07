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

  // Test reverse placement with chain constraint:
  // After placing all arrows in reverse (arrows[0] .. arrows[k]):
  // In the real game, arrows[k] is removed FIRST, then arrows[k-1], ..., down to arrows[0].
  // So at level start: ONLY arrows[k] is free!
  // When arrows[k] is removed: ONLY arrows[k-1] is free!
  // When arrows[k-1] is removed: ONLY arrows[k-2] is free!
  // This means:
  // For each i in 0 .. k-1:
  // arrows[i]'s exit ray MUST be blocked by arrows[i+1]!
  // (It can ALSO be blocked by arrows[i+2..k], but it MUST be blocked by arrows[i+1] so that when arrows[i+1] is removed, arrows[i] is unblocked!)
  // And arrows[i]'s exit ray must NOT be blocked by arrows[0..i-1]!
  //
  // Let's test generating this exact chain R_n -> R_{n-1} -> ... -> R_1!
  for (var seed = 0; seed < 5; seed++) {
    final rng = Random(seed);
    final free = <GridCell>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (mask[r * cols + c]) free.add(GridCell(r, c));
      }
    }
    final occupied = <GridCell, String>{};
    final chain = <Arrow>[];

    // Rn: any arrow with clear exit ray
    final first = findArrowWithClearRay(free, occupied, rows, cols, mask, rng, 'a0');
    if (first == null) continue;
    chain.add(first);
    for (final c in first.path) {
      free.remove(c);
      occupied[c] = first.id;
    }

    // Now place R_{k-1}:
    // To block chain.last (R_k), R_{k-1}'s BODY must lie on chain.last's exit ray!
    // And R_{k-1}'s OWN exit ray must be clear (or clear of all already-placed arrows)!
    // Notice: since R_{k-1}'s exit ray must not hit already-placed arrows, it must exit through FREE cells!
    while (chain.length < maxArrows && free.isNotEmpty) {
      final prev = chain.last;
      final prevRay = getExitRay(prev, rows, cols);
      // All cells on prevRay that are currently free:
      final rayFree = prevRay.where((c) => free.contains(c)).toList();
      if (rayFree.isEmpty) {
        // prev's exit ray is already blocked or hits board edge!
        break;
      }

      // We want to find an arrow in free cells whose path intersects rayFree,
      // and whose head has a clear exit ray (hits no occupied cells).
      rayFree.shuffle(rng);
      Arrow? nextArrow;

      // Try placing arrow where anchor in rayFree is part of its body
      for (final anchor in rayFree) {
        final candidates = findArrowsContaining(anchor, free, occupied, rows, cols, mask, rng, 'a${chain.length}');
        if (candidates.isNotEmpty) {
          nextArrow = candidates.first;
          break;
        }
      }

      if (nextArrow == null) {
        // Could not find an arrow crossing prev's ray
        break;
      }

      chain.add(nextArrow);
      for (final c in nextArrow.path) {
        free.remove(c);
        occupied[c] = nextArrow.id;
      }
    }

    print('Seed $seed: Chain length = ${chain.length}');
    if (chain.length >= 10) {
      final board = Board(rows: rows, cols: cols, mask: mask, arrows: chain);
      final m = DifficultyConfig.evaluate(board);
      print('  maxWave=${m.maxFreeWave}, free0=${m.free0}, avgFree=${m.avgFree}');
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

Arrow? findArrowWithClearRay(Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng, String id) {
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

List<Arrow> findArrowsContaining(GridCell anchor, Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Random rng, String id) {
  final result = <Arrow>[];
  // An arrow containing anchor can have anchor as head, tail, or body cell!
  // Let's test all possible heads in free (including anchor itself, or cells around anchor)
  // Distance from anchor <= 4
  final potentialHeads = free.where((c) => (c.row - anchor.row).abs() + (c.col - anchor.col).abs() <= 4).toList()..shuffle(rng);

  for (final head in potentialHeads) {
    if (result.length >= 5) break;
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      if (!isRayClear(head, dir, occupied, rows, cols)) continue;
      final targetLen = 3 + rng.nextInt(3);
      // We need a path starting at head, walking backwards, that contains anchor!
      final path = walkBackwardsContaining(head, dir, targetLen, anchor, free, rows, cols, mask, rng);
      if (path != null && path.length >= 3) {
        result.add(Arrow(id: id, path: path, dir: dir));
        break;
      }
    }
  }
  return result;
}

List<GridCell>? walkBackwardsContaining(GridCell head, Direction forwardDir, int targetLen, GridCell anchor, Set<GridCell> free, int rows, int cols, List<bool> mask, Random rng) {
  final backwardsDir = forwardDir.opposite;
  final path = <GridCell>[head];
  final claimed = <GridCell>{head};
  var current = head;
  var currentBackDir = backwardsDir;

  while (path.length < targetLen) {
    // If not yet claimed anchor, bias towards anchor
    final candidates = [currentBackDir, turnLeft(currentBackDir), turnRight(currentBackDir)];
    candidates.sort((a, b) {
      final stepA = current.shift(a);
      final stepB = current.shift(b);
      final distA = (stepA.row - anchor.row).abs() + (stepA.col - anchor.col).abs();
      final distB = (stepB.row - anchor.row).abs() + (stepB.col - anchor.col).abs();
      return distA.compareTo(distB);
    });

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
    if (current == anchor) break;
  }

  if (!claimed.contains(anchor)) return null;
  return path.reversed.toList();
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

