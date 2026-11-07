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

  // 1. Generate full dense board with 28 arrows
  final free = <GridCell>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (mask[r * cols + c]) free.add(GridCell(r, c));
    }
  }
  final occupied = <GridCell, String>{};
  final arrows = <Arrow>[];

  while (arrows.length < maxArrows && free.isNotEmpty) {
    final starts = free.toList()..shuffle(rng);
    Arrow? best;
    for (final head in starts) {
      if (best != null) break;
      final dirs = [...DirectionX.orthogonal]..shuffle(rng);
      for (final dir in dirs) {
        var cell = head.shift(dir);
        var clear = true;
        while (cell.inside(rows, cols)) {
          if (occupied.containsKey(cell)) {
            clear = false;
            break;
          }
          cell = cell.shift(dir);
        }
        if (!clear) continue;
        final path = walkBackwards(head, dir, 3 + rng.nextInt(3), free, rows, cols, mask, rng);
        if (path.length >= 3) {
          best = Arrow(id: 'a${arrows.length}', path: path, dir: dir);
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

  // Optimize orientations:
  // For each arrow, it has a path [c0, c1, ..., c_k].
  // It can be oriented forward (dir from c_{k-1} to c_k) OR backward (dir from c_1 to c_0)!
  // If backward orientation has a valid direction and doesn't create cycles, which is better?
  // Let's test checking all 2^k orientations or greedy flipping!
  var currentBoard = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
  var currentMetrics = DifficultyConfig.evaluate(currentBoard);
  print('Initial: arrows=${arrows.length}, maxWave=${currentMetrics.maxFreeWave}, free0=${currentMetrics.free0}, avgFree=${currentMetrics.avgFree}');

  // Greedy flip pass
  for (var round = 0; round < 5; round++) {
    var flippedAny = false;
    for (var i = 0; i < arrows.length; i++) {
      final a = arrows[i];
      // Try reversing arrow
      final reversedPath = a.path.reversed.toList();
      final revDir = lastStepDirection(reversedPath);
      if (revDir == null) continue;

      final reversedArrow = Arrow(id: a.id, path: reversedPath, dir: revDir);
      final testArrows = List<Arrow>.from(arrows);
      testArrows[i] = reversedArrow;
      final testBoard = Board(rows: rows, cols: cols, mask: mask, arrows: testArrows);

      if (solver.solvableByGreedy(testBoard)) {
        final m = DifficultyConfig.evaluate(testBoard);
        if (m.maxFreeWave < currentMetrics.maxFreeWave ||
            (m.maxFreeWave == currentMetrics.maxFreeWave && m.avgFree < currentMetrics.avgFree)) {
          arrows[i] = reversedArrow;
          currentBoard = testBoard;
          currentMetrics = m;
          flippedAny = true;
          print('Flipped arrow ${a.id}: maxWave now ${m.maxFreeWave}, free0 now ${m.free0}, avgFree now ${m.avgFree}');
        }
      }
    }
    if (!flippedAny) break;
  }
}

Direction? lastStepDirection(List<GridCell> path) {
  if (path.length < 2) return null;
  final a = path[path.length - 2];
  final b = path.last;
  final dr = b.row - a.row;
  final dc = b.col - a.col;
  if (dr == -1 && dc == 0) return Direction.up;
  if (dr == 1 && dc == 0) return Direction.down;
  if (dc == -1 && dr == 0) return Direction.left;
  if (dc == 1 && dr == 0) return Direction.right;
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

