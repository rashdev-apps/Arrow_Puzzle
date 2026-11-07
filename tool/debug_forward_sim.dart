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

  // Generate dense board with reverse placement
  final free = <GridCell>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (mask[r * cols + c]) free.add(GridCell(r, c));
    }
  }
  final occupied = <GridCell, String>{};
  final arrows = <Arrow>[];

  // While free is not empty, generate candidate arrows whose exit ray is clear of current occupied
  while (arrows.length < maxArrows && free.isNotEmpty) {
    final starts = free.toList()..shuffle(rng);
    Arrow? picked;

    for (final head in starts) {
      if (picked != null) break;
      final dirs = [...DirectionX.orthogonal]..shuffle(rng);
      for (final dir in dirs) {
        if (!isRayClear(head, dir, occupied, rows, cols)) continue;
        final targetLen = 3 + rng.nextInt(3);
        final path = walkBackwards(head, dir, targetLen, free, rows, cols, mask, rng);
        if (path.length >= 3) {
          picked = Arrow(id: 'a${arrows.length}', path: path, dir: dir);
          break;
        }
      }
    }

    if (picked == null) break;
    arrows.add(picked);
    for (final c in picked.path) {
      free.remove(c);
      occupied[c] = picked.id;
    }
  }

  print('Dense arrows placed: ${arrows.length}');
  final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
  print('Solvable: ${solver.solvableByGreedy(board)}');
  final m = DifficultyConfig.evaluate(board);
  print('maxFreeWave: ${m.maxFreeWave}, free0: ${m.free0}, avgFree: ${m.avgFree}');
}

bool isRayClear(GridCell head, Direction dir, Map<GridCell, String> occupied, int rows, int cols) {
  var c = head.shift(dir);
  while (c.inside(rows, cols)) {
    if (occupied.containsKey(c)) return false;
    c = c.shift(dir);
  }
  return true;
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

