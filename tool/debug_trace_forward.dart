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
  final rng = Random(0);

  final free = <GridCell>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (mask[r * cols + c]) free.add(GridCell(r, c));
    }
  }
  final occupied = <GridCell, String>{};
  final placed = <Arrow>[];

  final a1 = findArrowWithRayToEdge(free, rows, cols, mask, rng, 'a1')!;
  placed.add(a1);
  for (final c in a1.path) {
    free.remove(c);
    occupied[c] = a1.id;
  }

  // Check board with just a1
  var board = Board(rows: rows, cols: cols, mask: mask, arrows: placed);
  print('With a1: free = ${board.freeArrows({'a1'}).map((a) => a.id).toList()}');

  // Place a2
  final a2 = findArrowBlockedBy(
    targetArrow: a1,
    allPlaced: placed,
    free: free,
    occupied: occupied,
    rows: rows,
    cols: cols,
    mask: mask,
    rng: rng,
    id: 'a2',
  )!;
  placed.add(a2);
  for (final c in a2.path) {
    free.remove(c);
    occupied[c] = a2.id;
  }

  // Check board with a1, a2
  board = Board(rows: rows, cols: cols, mask: mask, arrows: placed);
  print('With a1, a2: free = ${board.freeArrows({'a1', 'a2'}).map((a) => a.id).toList()}');
  // Did a2 block a1?
  print('a1 exit ray: ${board.exitRay(a1)}');
  print('a2 path: ${a2.path}');
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
      final path = walkBackwards(head, dir, 3, free, rows, cols, mask, rng);
      if (path.length >= 3) return Arrow(id: id, path: path, dir: dir);
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
      var c = head.shift(dir);
      var hitTarget = false;
      var hitOtherFirst = false;
      while (c.inside(rows, cols)) {
        if (targetCells.contains(c)) {
          hitTarget = true;
          break;
        }
        if (occupied.containsKey(c)) {
          hitOtherFirst = true;
          break;
        }
        c = c.shift(dir);
      }
      if (!hitTarget || hitOtherFirst) continue;
      final path = walkBackwards(head, dir, 3, free, rows, cols, mask, rng);
      if (path.length >= 3) return Arrow(id: id, path: path, dir: dir);
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

