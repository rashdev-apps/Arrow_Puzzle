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

  // Let's test placing arrows where:
  // We maintain a list of placed arrows: arrows = []
  //
  // For chain puzzle:
  // At any step, we simulate solving the board:
  // free = board.freeArrows()
  // We want free.length <= allowedMaxFree (1 or 2)!
  //
  // Can we build the board forward or backward?
  // Let's test forward:
  // At step 1: Place arrow A1.
  // A1 must be free (its exit ray must be clear to the boundary).
  //
  // At step 2: Place arrow A2.
  // Before A1 is removed, A2 MUST be blocked by A1!
  // And after A1 is removed, A2 MUST be free!
  //
  // At step 3: Place arrow A3.
  // Before A2 is removed, A3 MUST be blocked by A2 (or A1)!
  // And after A1 and A2 are removed, A3 MUST be free!
  //
  // At step k: Place arrow Ak.
  // Before A(k-1) is removed, Ak MUST be blocked by A(k-1)!
  // And after A1..A(k-1) are removed, Ak MUST be free!
  //
  // Let's test this!
  // How to place Ak?
  // Ak's head points in direction dir.
  // Its exit ray:
  // The first arrow that Ak's exit ray hits MUST be A(k-1)!
  // And all other cells on Ak's exit ray before hitting A(k-1) must be FREE cells!
  // And after passing through A(k-1), what can Ak's exit ray hit?
  // ONLY arrows in {A1 .. A(k-2)} or the edge! It must NOT hit any arrows not yet removed!
  //
  // WOW! Let's check that:
  // If Ak's exit ray:
  // 1. Goes through free cells.
  // 2. Hits A(k-1) (or A(k-1)'s cells).
  // 3. Continues, and only hits already-placed arrows {A1..A(k-1)} before reaching the board edge!
  // THEN:
  // While A(k-1) is on the board, Ak is BLOCKED by A(k-1)!
  // When A1, A2, ..., A(k-1) are ALL removed, Ak's exit ray has NO arrows left in front of it!
  // So Ak BECOMES FREE!
  // And because Ak is blocked by A(k-1), Ak CANNOT be removed before A(k-1)!
  // Therefore, the removal order is STRICTLY A1 -> A2 -> A3 -> ... -> Ak!
  //
  // Let's test this forward placement in Dart right now!
  for (var seed = 0; seed < 5; seed++) {
    final rng = Random(seed);
    final free = <GridCell>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (mask[r * cols + c]) free.add(GridCell(r, c));
      }
    }
    final occupied = <GridCell, String>{};
    final placed = <Arrow>[];

    // Place A1: any arrow whose exit ray goes straight to edge through free cells!
    final a1 = findArrowWithRayToEdge(free, rows, cols, mask, rng, 'a1');
    if (a1 == null) {
      print('Seed $seed: A1 failed');
      continue;
    }
    placed.add(a1);
    for (final c in a1.path) {
      free.remove(c);
      occupied[c] = a1.id;
    }

    // Now place A2, A3, ...
    while (placed.length < maxArrows && free.isNotEmpty) {
      final prev = placed.last;
      final prevCells = prev.cells;

      // Find an arrow Ak in free cells such that:
      // Ak's exit ray hits prevCells FIRST among all placed arrows!
      // And beyond prevCells, it only hits already-placed arrows or the edge!
      final ak = findArrowBlockedBy(
        targetArrow: prev,
        allPlaced: placed,
        free: free,
        occupied: occupied,
        rows: rows,
        cols: cols,
        mask: mask,
        rng: rng,
        id: 'a${placed.length + 1}',
      );

      if (ak == null) {
        break;
      }

      placed.add(ak);
      for (final c in ak.path) {
        free.remove(c);
        occupied[c] = ak.id;
      }
    }

    print('Seed $seed: Forward chain length = ${placed.length}');
    if (placed.length >= 5) {
      final board = Board(rows: rows, cols: cols, mask: mask, arrows: placed);
      final m = DifficultyConfig.evaluate(board);
      print('  Solvable: ${solver.solvableByGreedy(board)}, maxWave=${m.maxFreeWave}, free0=${m.free0}, avgFree=${m.avgFree}');
    }
  }
}

Arrow? findArrowWithRayToEdge(Set<GridCell> free, int rows, int cols, List<bool> mask, Random rng, String id) {
  final heads = free.toList()..shuffle(rng);
  for (final head in heads) {
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      // Ray to edge must pass only through free cells
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
      if (path.length >= 3) {
        return Arrow(id: id, path: path, dir: dir);
      }
    }
  }
  return null;
}

Arrow? findArrowBlockedBy({
  required Arrow targetArrow,
  required List<Arrow> allPlaced,
  required Set<GridCell> free,
  required Map<GridCell, String> occupied,
  required int rows,
  required int cols,
  required List<bool> mask,
  required Random rng,
  required String id,
}) {
  final targetCells = targetArrow.cells;
  final heads = free.toList()..shuffle(rng);

  for (final head in heads) {
    final dirs = [...DirectionX.orthogonal]..shuffle(rng);
    for (final dir in dirs) {
      // Check ray from head:
      var c = head.shift(dir);
      var hitTarget = false;
      var hitOtherFirst = false;

      while (c.inside(rows, cols)) {
        if (targetCells.contains(c)) {
          hitTarget = true;
          break; // Hit target!
        }
        if (occupied.containsKey(c)) {
          // Hit an occupied cell that is NOT target!
          hitOtherFirst = true;
          break;
        }
        c = c.shift(dir);
      }

      if (!hitTarget || hitOtherFirst) continue;

      // Beyond target, does the ray hit anything outside allPlaced?
      // Since all other occupied cells ARE in allPlaced, they will already be gone when target is removed!
      // So as long as it reaches edge (only hitting cells in free or occupied), it's good!

      final path = walkBackwards(head, dir, 3 + rng.nextInt(3), free, rows, cols, mask, rng);
      if (path.length >= 3) {
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

