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

  extendTails(arrows, free, occupied, rows, cols);

  // In each step of the solve, if there are > 1 free arrows:
  // Can we make all except 1 point to something else?
  var currentBoard = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);

  for (var pass = 0; pass < 20; pass++) {
    var improved = false;
    for (var i = 0; i < arrows.length; i++) {
      final a = arrows[i];
      // Try both orientations (forward and reversed path), and all 4 directions for head
      final candidateArrows = <Arrow>[];

      // Option 1: same path, 4 directions
      for (final d in DirectionX.orthogonal) {
        if (d != a.dir) candidateArrows.add(Arrow(id: a.id, path: a.path, dir: d));
      }
      // Option 2: reversed path, 4 directions
      final rev = a.path.reversed.toList();
      for (final d in DirectionX.orthogonal) {
        candidateArrows.add(Arrow(id: a.id, path: rev, dir: d));
      }

      for (final cand in candidateArrows) {
        final testArrows = List<Arrow>.from(arrows);
        testArrows[i] = cand;
        final testBoard = Board(rows: rows, cols: cols, mask: mask, arrows: testArrows);
        if (solver.solvableByGreedy(testBoard)) {
          final mCurrent = DifficultyConfig.evaluate(currentBoard);
          final mTest = DifficultyConfig.evaluate(testBoard);
          if (mTest.maxFreeWave < mCurrent.maxFreeWave ||
              (mTest.maxFreeWave == mCurrent.maxFreeWave && mTest.avgFree < mCurrent.avgFree)) {
            arrows[i] = cand;
            currentBoard = testBoard;
            improved = true;
            print('Pass $pass: Arrow ${a.id} optimized -> maxWave=${mTest.maxFreeWave}, free0=${mTest.free0}, avgFree=${mTest.avgFree}');
            break;
          }
        }
      }
    }
    if (!improved) break;
  }

  final finalMetrics = DifficultyConfig.evaluate(currentBoard);
  print('FINAL: maxWave=${finalMetrics.maxFreeWave}, free0=${finalMetrics.free0}, avgFree=${finalMetrics.avgFree}');
}

void extendTails(List<Arrow> arrows, Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols) {
  var changed = true;
  while (changed && free.isNotEmpty) {
    changed = false;
    for (final cell in free.toList()) {
      for (var i = 0; i < arrows.length; i++) {
        final arrow = arrows[i];
        final tail = arrow.tail;
        if ((tail.row - cell.row).abs() + (tail.col - cell.col).abs() == 1) {
          arrows[i] = Arrow(id: arrow.id, path: [cell, ...arrow.path], dir: arrow.dir);
          occupied[cell] = arrow.id;
          free.remove(cell);
          changed = true;
          break;
        }
      }
      if (changed) break;
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

