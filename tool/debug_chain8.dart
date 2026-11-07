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
  // We place R_n first.
  // Then R_{n-1}, ..., R_1.
  //
  // For R_k (the one placed at step i):
  // R_k's exit ray MUST be completely clear of all ALREADY-PLACED arrows {R_{k+1} .. R_n}!
  // BUT R_k's body MUST block the exit ray of R_{k+1}!
  //
  // Why did it stop at 13 arrows before?
  // Because we searched for an arrow whose body intersects R_{k+1}'s exit ray AND whose own ray is clear.
  // Let's see: what if R_{k+1}'s exit ray hits the board edge or has only 1-2 free cells?
  // If R_k has length 3-6, its body only needs 1 cell on R_{k+1}'s ray!
  // And its head can be anywhere in free cells as long as head -> edge is free of {R_{k+1} .. R_n}!
  //
  // Let's improve the search for R_k!
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

    // Place Rn
    final rn = findArrowWithRayToEdge(free, rows, cols, mask, rng, 'a0');
    if (rn == null) continue;
    chain.add(rn);
    for (final c in rn.path) {
      free.remove(c);
      occupied[c] = rn.id;
    }

    var attempts = 0;
    while (chain.length < maxArrows && free.isNotEmpty && attempts < 100) {
      attempts++;
      final prev = chain.last;
      final prevRay = getExitRay(prev, rows, cols);
      final rayFree = prevRay.where((c) => free.contains(c)).toSet();

      // Find an arrow X in free cells such that:
      // 1. X's body has at least 1 cell in rayFree (so X blocks prev!)
      // 2. X's exit ray has NO cells in occupied (so X is clear of already-placed arrows!)
      final cand = findArrowBlocking(
        rayFree: rayFree,
        free: free,
        occupied: occupied,
        rows: rows,
        cols: cols,
        mask: mask,
        rng: rng,
        id: 'a${chain.length}',
      );

      if (cand != null) {
        chain.add(cand);
        for (final c in cand.path) {
          free.remove(c);
          occupied[c] = cand.id;
        }
        attempts = 0;
      } else {
        // If we couldn't block prev directly, can we branch?
        // Branching means blocking another arrow in chain that is currently free!
        // Which arrows in chain are currently unblocked?
        final unblocked = chain.where((a) {
          final ray = getExitRay(a, rows, cols);
          return !ray.any((c) => occupied.containsKey(c));
        }).toList();

        var foundBranch = false;
        for (final u in unblocked.reversed.skip(1)) {
          final uRay = getExitRay(u, rows, cols).where((c) => free.contains(c)).toSet();
          if (uRay.isEmpty) continue;
          final branchCand = findArrowBlocking(
            rayFree: uRay,
            free: free,
            occupied: occupied,
            rows: rows,
            cols: cols,
            mask: mask,
            rng: rng,
            id: 'a${chain.length}',
          );
          if (branchCand != null) {
            chain.add(branchCand);
            for (final c in branchCand.path) {
              free.remove(c);
              occupied[c] = branchCand.id;
            }
            attempts = 0;
            foundBranch = true;
            break;
          }
        }
        if (!foundBranch) break;
      }
    }

    print('Seed $seed: Chain length = ${chain.length}');
    if (chain.length >= 10) {
      // In chain, chain.last was placed last, so it will be removed FIRST.
      final board = Board(rows: rows, cols: cols, mask: mask, arrows: chain);
      final m = DifficultyConfig.evaluate(board);
      print('  Solvable: ${solver.solvableByGreedy(board)}, maxWave=${m.maxFreeWave}, free0=${m.free0}, avgFree=${m.avgFree}, cov=${(m.coverage*100).toStringAsFixed(1)}%');
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

Arrow? findArrowWithRayToEdge(Set<GridCell> free, int rows, int cols, List<bool> mask, Random rng, String id) {
  final heads = free.toList()..shuffle(rng);
  for (final head in heads) {
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      var c = head.shift(dir);
      var clear = true;
      while (c.inside(rows, cols)) {
        if (!free.contains(c)) {
          clear = false;
          break;
        }
        c = c.shift(dir);
      }
      if (!clear) continue;
      final path = walkBackwards(head, dir, 3 + rng.nextInt(3), free, rows, cols, mask, rng);
      if (path.length >= 3) return Arrow(id: id, path: path, dir: dir);
    }
  }
  return null;
}

Arrow? findArrowBlocking({
  required Set<GridCell> rayFree,
  required Set<GridCell> free,
  required Map<GridCell, String> occupied,
  required int rows,
  required int cols,
  required List<bool> mask,
  required Random rng,
  required String id,
}) {
  if (rayFree.isEmpty) return null;
  // Look for any arrow in free whose path contains at least one cell in rayFree,
  // and whose head -> edge does not hit any occupied cell!
  final heads = free.toList()..shuffle(rng);
  for (final head in heads) {
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      // Check head exit ray: must NOT hit occupied!
      var c = head.shift(dir);
      var clear = true;
      while (c.inside(rows, cols)) {
        if (occupied.containsKey(c)) {
          clear = false;
          break;
        }
        c = c.shift(dir);
      }
      if (!clear) continue;

      // Generate random walk backward from head
      final targetLen = 3 + rng.nextInt(4);
      final path = walkBackwards(head, dir, targetLen, free, rows, cols, mask, rng);
      if (path.length >= 3 && path.any((p) => rayFree.contains(p))) {
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

