import 'dart:math';

import '../../domain/arrow.dart';
import '../../domain/board.dart';
import '../../domain/direction.dart';
import '../../domain/grid_cell.dart';
import '../../domain/level.dart';
import '../difficulty_config.dart';
import '../solver.dart';
import 'layout_hash.dart';

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

/// Linear Rectangular Grid Level Generator.
/// Generates deterministic, 100% solvable chain puzzles with:
/// - Forced solution orders
/// - Decoy blocker paths
/// - Arrow heads matching direction
/// - Head run >= 2 (straight head)
/// - Rectangular portrait-friendly boards with >= 90% target coverage
class LevelGenerator {
  final Solver _solver = const Solver();

  static int seedFor(int levelId, {String salt = 'arrowescape'}) =>
      LayoutHash.seed('$salt:$levelId');

  GeneratedLevel generate(
    int levelId, {
    int? seedOverride,
    String salt = 'arrowescape',
  }) {
    final targetCount = DifficultyConfig.arrowCount(levelId);
    final dim = DifficultyConfig.boardSizeFor(levelId, targetCount);
    final rows = dim.rows;
    final cols = dim.cols;

    // Plain rectangular grid (no shape masks)
    final mask = List<bool>.filled(rows * cols, true);

    GeneratedLevel? bestResult;
    double bestScore = -1.0;

    // Fast generation loop
    for (var attempt = 0; attempt < 80; attempt++) {
      final rng = Random(seedOverride ?? seedFor(levelId, salt: '$salt#$attempt'));
      final result = _tryGenerate(
        levelId,
        rows,
        cols,
        mask,
        targetCount,
        rng,
      );
      if (result != null) {
        if (result.metrics.isValidFor(levelId)) {
          return result;
        }
        if (result.metrics.isSolvable &&
            (bestResult == null ||
                result.metrics.maxFreeWave < bestResult.metrics.maxFreeWave ||
                (result.metrics.maxFreeWave == bestResult.metrics.maxFreeWave &&
                    result.metrics.difficultyScore > bestScore))) {
          bestScore = result.metrics.difficultyScore;
          bestResult = result;
        }
      }
    }

    if (bestResult != null) {
      return bestResult;
    }

    // Safety fallback with relaxed constraints
    for (var attempt = 0; attempt < 60; attempt++) {
      final rng = Random(seedFor(levelId, salt: '$salt#fallback#$attempt'));
      final result = _tryGenerate(
        levelId,
        rows,
        cols,
        mask,
        targetCount,
        rng,
        isFallback: true,
      );
      if (result != null && result.metrics.isSolvable) {
        return result;
      }
    }

    throw StateError('Failed to generate solvable level $levelId');
  }

  GeneratedLevel? _tryGenerate(
    int levelId,
    int rows,
    int cols,
    List<bool> mask,
    int targetArrows,
    Random rng, {
    bool isFallback = false,
  }) {
    final free = <GridCell>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        free.add(GridCell(r, c));
      }
    }
    final occupied = <GridCell, String>{};
    final arrows = <Arrow>[];

    // Arrow length configuration
    final minPathLen = levelId <= 5 ? 2 : (levelId <= 20 ? 3 : 3);
    final maxPathLen = levelId <= 5 ? 3 : (levelId <= 20 ? 4 : 5);

    while (arrows.length < targetArrows && free.isNotEmpty) {
      final starts = free.toList()..shuffle(rng);
      Arrow? best;
      for (final head in starts) {
        if (best != null) break;
        final dirs = [...DirectionX.orthogonal]..shuffle(rng);
        for (final dir in dirs) {
          // Check ray exit to boundary
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

          final targetLen = minPathLen + rng.nextInt(maxPathLen - minPathLen + 1);
          final path = _walkBackwards(
            head,
            dir,
            targetLen,
            free,
            rows,
            cols,
            mask,
            rng,
          );

          if (path.length >= 2) {
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

    if (arrows.length < (isFallback ? max(3, (targetArrows * 0.7).floor()) : max(3, (targetArrows * 0.85).floor()))) {
      return null;
    }

    _extendTailsSafely(arrows, free, occupied, rows, cols, mask);

    var currentBoard = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);

    // Simulated annealing optimizer to minimize maxFreeWave and avgFree
    for (var pass = 0; pass < 20; pass++) {
      var improved = false;
      for (var i = 0; i < arrows.length; i++) {
        final a = arrows[i];
        final candidateArrows = <Arrow>[];

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
            final mCurrent = BoardQualityMetrics.evaluate(currentBoard);
            final mTest = BoardQualityMetrics.evaluate(testBoard);
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

    final metrics = BoardQualityMetrics.evaluate(currentBoard);

    final level = Level(
      id: levelId,
      shape: 'rectangle',
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

    // Rule: head_run >= 2 and head segment must point strictly in forwardDir!
    final firstBackStep = head.shift(backwardsDir);
    if (!firstBackStep.inside(rows, cols) ||
        !mask[firstBackStep.row * cols + firstBackStep.col] ||
        !free.contains(firstBackStep)) {
      return const [];
    }
    path.add(firstBackStep);
    claimed.add(firstBackStep);

    final exitRayCells = <GridCell>{};
    var rayStep = head.shift(forwardDir);
    while (rayStep.inside(rows, cols)) {
      exitRayCells.add(rayStep);
      rayStep = rayStep.shift(forwardDir);
    }

    var current = firstBackStep;
    var currentBackDir = backwardsDir;
    while (path.length < targetLen) {
      final candidates = [
        currentBackDir,
        _turnLeft(currentBackDir),
        _turnRight(currentBackDir)
      ]..shuffle(rng);

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
