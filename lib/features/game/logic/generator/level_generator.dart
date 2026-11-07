import 'dart:math';

import '../../domain/arrow.dart';
import '../../domain/board.dart';
import '../../domain/direction.dart';
import '../../domain/grid_cell.dart';
import '../../domain/level.dart';
import '../difficulty_config.dart';
import '../solver.dart';
import 'layout_hash.dart';
import 'shapes.dart';

class GeneratedLevel {
  final Level level;
  final List<String> solutionOrder;
  final int longestChain;
  final int freeAtStart;
  final double coverage;
  final BoardQualityMetrics metrics;

  const GeneratedLevel({
    required this.level,
    required this.solutionOrder,
    required this.longestChain,
    required this.freeAtStart,
    required this.coverage,
    required this.metrics,
  });

  double get difficultyScore => level.difficulty;
}

class LevelGenerator {
  final Solver _solver = const Solver();

  static int seedFor(int levelId, {String salt = 'arrowescape'}) =>
      LayoutHash.seed('$salt:$levelId');

  GeneratedLevel generate(
    int levelId,
    ShapeMask shape, {
    int? seedOverride,
    String salt = 'arrowescape',
  }) {
    final (minArrows, maxArrows) = DifficultyConfig.targetArrowCount(levelId);
    final scaled = _fitAspect(shape, levelId);
    final rows = scaled.baseRows;
    final cols = scaled.baseCols;
    final mask = scaled.toMask();

    GeneratedLevel? bestResult;
    double bestScore = -1.0;

    for (var attempt = 0; attempt < 80; attempt++) {
      final rng = Random(seedOverride ?? seedFor(levelId, salt: '$salt#$attempt'));
      final result = _tryGenerate(
        levelId,
        shape.name,
        rows,
        cols,
        mask,
        minArrows,
        maxArrows,
        rng,
      );
      if (result != null) {
        if (result.metrics.isValidFor(levelId)) {
          return result;
        }
        if (result.metrics.isSolvable && (bestResult == null || result.metrics.maxFreeWave < bestResult.metrics.maxFreeWave || (result.metrics.maxFreeWave == bestResult.metrics.maxFreeWave && result.metrics.difficultyScore > bestScore))) {
          bestScore = result.metrics.difficultyScore;
          bestResult = result;
        }
      }
    }

    if (bestResult != null) {
      return bestResult;
    }

    for (var attempt = 0; attempt < 50; attempt++) {
      final rng = Random(seedFor(levelId, salt: '$salt#fallback#$attempt'));
      final result = _tryGenerate(
        levelId,
        shape.name,
        rows,
        cols,
        mask,
        15,
        maxArrows,
        rng,
      );
      if (result != null && result.metrics.isSolvable) {
        return result;
      }
    }

    throw StateError('Failed to generate solvable level $levelId after 130 attempts');
  }

  ShapeMask _fitAspect(ShapeMask shape, int levelId) {
    // For any shape, calculate target cell count from desired arrow count.
    final (minArrows, maxArrows) = DifficultyConfig.targetArrowCount(levelId);
    final targetN = (minArrows + maxArrows) / 2.0;
    // Each arrow takes around 4.0 to 4.5 cells on average
    final targetCells = targetN * 4.3;

    final nativeCells = shape.cells.length;
    final scale = sqrt(targetCells / nativeCells);
    var rows = (shape.baseRows * scale).round();
    var cols = (shape.baseCols * scale).round();

    // Limit maximum dimensions for performance and screen layout
    if (cols > 28) {
      final ratio = 28 / cols;
      cols = 28;
      rows = (rows * ratio).round();
    }
    if (rows > 28) {
      final ratio = 28 / rows;
      rows = 28;
      cols = (cols * ratio).round();
    }
    return shape.resized(max(10, rows), max(10, cols));
  }

  GeneratedLevel? _tryGenerate(
    int levelId,
    String shapeName,
    int rows,
    int cols,
    List<bool> mask,
    int minArrows,
    int maxArrows,
    Random rng,
  ) {
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
          final path = _walkBackwards(head, dir, 3 + rng.nextInt(3), free, rows, cols, mask, rng);
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

    if (arrows.length < 15) return null;

    _extendTailsSafely(arrows, free, occupied, rows, cols, mask);

    var currentBoard = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);

    // Simulated annealing optimizer to minimize maxFreeWave and avgFree
    for (var pass = 0; pass < 25; pass++) {
      var improved = false;
      for (var i = 0; i < arrows.length; i++) {
        final a = arrows[i];
        final candidateArrows = <Arrow>[];

        // The only valid direction for an arrow is the direction of its last segment!
        // We can test reversing the path so the tail becomes the head, with the new head's dir
        // pointing strictly along the reversed path's last segment.
        if (a.path.length >= 2) {
          final rev = a.path.reversed.toList();
          final prev = rev[rev.length - 2];
          final head = rev.last;
          final dr = head.row - prev.row;
          final dc = head.col - prev.col;
          Direction? revDir;
          if (dr == -1 && dc == 0) revDir = Direction.up;
          if (dr == 1 && dc == 0) revDir = Direction.down;
          if (dc == -1 && dr == 0) revDir = Direction.left;
          if (dc == 1 && dr == 0) revDir = Direction.right;
          if (revDir != null) {
            // Verify reversed arrow does not point to its own body/tail
            final ownBody = rev.sublist(0, rev.length - 1).toSet();
            var step = head.shift(revDir);
            var blocksSelf = false;
            while (step.inside(rows, cols)) {
              if (ownBody.contains(step)) {
                blocksSelf = true;
                break;
              }
              step = step.shift(revDir);
            }
            if (!blocksSelf) {
              candidateArrows.add(Arrow(id: a.id, path: rev, dir: revDir));
            }
          }
        }

        for (final cand in candidateArrows) {
          final testArrows = List<Arrow>.from(arrows);
          testArrows[i] = cand;
          final testBoard = Board(rows: rows, cols: cols, mask: mask, arrows: testArrows);
          if (_solver.solvableByGreedy(testBoard)) {
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

    final analysis = _solver.analyze(currentBoard);
    if (!analysis.isSolvable) return null;

    final metrics = DifficultyConfig.evaluate(currentBoard);

    final level = Level(
      id: levelId,
      shape: shapeName,
      board: currentBoard,
      parMoves: arrows.length,
      difficulty: metrics.difficultyScore,
      hash: LayoutHash.of(arrows),
    );

    return GeneratedLevel(
      level: level,
      solutionOrder: analysis.solutionOrder!,
      longestChain: analysis.longestChain,
      freeAtStart: analysis.freeAtStart,
      coverage: metrics.coverage,
      metrics: metrics,
    );
  }

  void _extendTailsSafely(
    List<Arrow> arrows,
    Set<GridCell> free,
    Map<GridCell, String> occupied,
    int rows,
    int cols,
    List<bool> mask,
  ) {
    var changed = true;
    while (changed && free.isNotEmpty) {
      changed = false;
      for (final cell in free.toList()) {
        for (var i = 0; i < arrows.length; i++) {
          final arrow = arrows[i];
          final tail = arrow.tail;
          if ((tail.row - cell.row).abs() + (tail.col - cell.col).abs() == 1) {
            // Never extend tail into the arrow's own exit ray!
            var rayStep = arrow.head.shift(arrow.dir);
            var blocksOwnRay = false;
            while (rayStep.inside(rows, cols)) {
              if (rayStep == cell) {
                blocksOwnRay = true;
                break;
              }
              rayStep = rayStep.shift(arrow.dir);
            }
            if (blocksOwnRay) continue;

            final oldArrow = arrows[i];
            arrows[i] = Arrow(id: arrow.id, path: [cell, ...arrow.path], dir: arrow.dir);
            final testBoard = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
            if (_solver.solvableByGreedy(testBoard)) {
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

  List<GridCell> _walkBackwards(
    GridCell head,
    Direction forwardDir,
    int targetLen,
    Set<GridCell> free,
    int rows,
    int cols,
    List<bool> mask,
    Random rng,
  ) {
    final backwardsDir = forwardDir.opposite;
    final path = <GridCell>[head];
    final claimed = <GridCell>{head};

    // The FIRST step backwards MUST be in backwardsDir so that the last segment
    // (from path[last-1] to head) points strictly in forwardDir!
    final firstBackStep = head.shift(backwardsDir);
    if (!firstBackStep.inside(rows, cols) ||
        !mask[firstBackStep.row * cols + firstBackStep.col] ||
        !free.contains(firstBackStep)) {
      return const [];
    }
    path.add(firstBackStep);
    claimed.add(firstBackStep);

    // Do not walk onto any cell that lies on the arrow's exit ray!
    // Otherwise the arrow's body/tail would curl around and block its own exit ray.
    final exitRayCells = <GridCell>{};
    var rayStep = head.shift(forwardDir);
    while (rayStep.inside(rows, cols)) {
      exitRayCells.add(rayStep);
      rayStep = rayStep.shift(forwardDir);
    }

    var current = firstBackStep;
    var currentBackDir = backwardsDir;
    while (path.length < targetLen) {
      final candidates = [currentBackDir, _turnLeft(currentBackDir), _turnRight(currentBackDir)]..shuffle(rng);
      GridCell? next;
      Direction? chosenDir;
      for (final d in candidates) {
        final step = current.shift(d);
        if (step.inside(rows, cols) &&
            mask[step.row * cols + step.col] &&
            free.contains(step) &&
            !claimed.contains(step) &&
            !exitRayCells.contains(step)) {
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

  Direction _turnLeft(Direction d) => switch (d) {
        Direction.up => Direction.left,
        Direction.left => Direction.down,
        Direction.down => Direction.right,
        Direction.right => Direction.up,
      };

  Direction _turnRight(Direction d) => switch (d) {
        Direction.up => Direction.right,
        Direction.right => Direction.down,
        Direction.down => Direction.left,
        Direction.left => Direction.up,
      };
}
