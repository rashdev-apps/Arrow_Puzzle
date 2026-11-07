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

  // Test: generate boards and see how quickly we find maxWave <= 2 (or 1)
  // For each level, we run multiple attempts with different random seeds.
  for (var id = 1; id <= 5; id++) {
    final maxAllowed = id <= 15 ? 2 : 1;
    BoardQualityMetrics? best;
    var foundAttempt = -1;

    for (var attempt = 0; attempt < 40; attempt++) {
      final rng = Random(id * 1000 + attempt);
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
        Arrow? picked;
        for (final head in starts) {
          if (picked != null) break;
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

      extendTailsSafely(arrows, free, occupied, rows, cols, mask, solver);

      var currentBoard = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);

      for (var pass = 0; pass < 25; pass++) {
        var improved = false;
        for (var i = 0; i < arrows.length; i++) {
          final a = arrows[i];
          final candidateArrows = <Arrow>[];
          for (final d in DirectionX.orthogonal) {
            if (d != a.dir) candidateArrows.add(Arrow(id: a.id, path: a.path, dir: d));
          }
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
                break;
              }
            }
          }
        }
        if (!improved) break;
      }

      final m = DifficultyConfig.evaluate(currentBoard);
      if (m.maxFreeWave <= maxAllowed && m.coverage >= 0.85) {
        best = m;
        foundAttempt = attempt;
        break;
      }
      if (best == null || m.maxFreeWave < best.maxFreeWave) {
        best = m;
        foundAttempt = attempt;
      }
    }

    print('Level $id: best attempt $foundAttempt, N=${best?.arrowCount}, maxWave=${best?.maxFreeWave}, free0=${best?.free0}, avgFree=${best?.avgFree}, cov=${((best?.coverage ?? 0)*100).toStringAsFixed(1)}%');
  }
}

void extendTailsSafely(List<Arrow> arrows, Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols, List<bool> mask, Solver solver) {
  var changed = true;
  while (changed && free.isNotEmpty) {
    changed = false;
    for (final cell in free.toList()) {
      for (var i = 0; i < arrows.length; i++) {
        final arrow = arrows[i];
        final tail = arrow.tail;
        if ((tail.row - cell.row).abs() + (tail.col - cell.col).abs() == 1) {
          final oldArrow = arrows[i];
          arrows[i] = Arrow(id: arrow.id, path: [cell, ...arrow.path], dir: arrow.dir);
          final testBoard = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
          if (solver.solvableByGreedy(testBoard)) {
            occupied[cell] = arrow.id;
            free.remove(cell);
            changed = true;
            break;
          } else {
            arrows[i] = oldArrow;
          }
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

