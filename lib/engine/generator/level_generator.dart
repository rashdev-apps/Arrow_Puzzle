import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../difficulty_config.dart';
import '../metrics/puzzle_metrics.dart';
import '../models/arrow.dart';
import '../models/board.dart';
import '../models/direction.dart';
import '../models/grid_cell.dart';
import '../models/level.dart';
import '../silhouette/silhouette_generator.dart';
import '../silhouette/silhouette_mask.dart';
import '../solver.dart';

class LevelGenerator {
  final SilhouetteGenerator _silhouetteGen = const SilhouetteGenerator();
  final Solver _solver = const Solver();

  static int hashSeed(int levelId, {String salt = 'arrowescape-v2'}) {
    final bytes = utf8.encode('$salt:$levelId');
    final digest = sha256.convert(bytes);
    final hex = digest.toString().substring(0, 8);
    return int.parse(hex, radix: 16);
  }

  Level generate(int levelId, {int? seedOverride, String salt = 'arrowescape-v2'}) {
    final seed = seedOverride ?? hashSeed(levelId, salt: salt);
    final rng = Random(seed);

    final targetArrows = DifficultyConfig.arrowCount(levelId);
    // Average segments per arrow: ~2.3 in early levels to ~3.5 in late levels
    final avgPathLen = levelId <= 5 ? 2.4 : (levelId <= 20 ? 2.8 : 3.4);
    final targetCells = (targetArrows * avgPathLen / 0.92).ceil();

    final silhouette = _silhouetteGen.generate(
      level: levelId,
      targetCells: targetCells,
      rng: rng,
    );

    // Chain puzzle arrow generation on silhouette
    final arrows = _generateChainPuzzle(
      levelId: levelId,
      silhouette: silhouette,
      targetArrows: targetArrows,
      rng: rng,
    );

    final board = Board(
      rows: silhouette.rows,
      cols: silhouette.cols,
      mask: silhouette.mask,
      arrows: arrows,
    );

    final analysis = _solver.analyze(board);
    final metrics = PuzzleQualityMetrics.evaluate(board, solver: _solver);

    return Level(
      id: levelId,
      seed: seed,
      board: board,
      silhouetteFamily: silhouette.family,
      solution: analysis.solutionOrder ?? arrows.map((a) => a.id).toList(),
      difficultyScore: metrics.difficultyScore,
      timeLimitSeconds: DifficultyConfig.computeTimeLimitSeconds(arrows.length, levelId),
    );
  }

  List<Arrow> _generateChainPuzzle({
    required int levelId,
    required SilhouetteMask silhouette,
    required int targetArrows,
    required Random rng,
  }) {
    final rows = silhouette.rows;
    final cols = silhouette.cols;
    final free = <GridCell>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (silhouette.mask[r * cols + c]) {
          free.add(GridCell(r, c));
        }
      }
    }

    final occupied = <GridCell, String>{};
    final arrows = <Arrow>[];

    final minPathLen = levelId <= 5 ? 2 : (levelId <= 20 ? 3 : 3);
    final maxPathLen = levelId <= 5 ? 3 : (levelId <= 20 ? 4 : 6);

    var attempts = 0;
    while (arrows.length < targetArrows && free.isNotEmpty && attempts < 2000) {
      attempts++;
      final starts = free.toList()..shuffle(rng);
      Arrow? best;

      for (final head in starts) {
        if (best != null) break;
        final dirs = [...Direction.orthogonal]..shuffle(rng);
        for (final dir in dirs) {
          // Check ray exit to boundary across silhouette mask
          var cell = head.shift(dir);
          var rayClear = true;
          while (cell.inside(rows, cols)) {
            if (occupied.containsKey(cell)) {
              rayClear = false;
              break;
            }
            cell = cell.shift(dir);
          }
          if (!rayClear) continue;

          // Build valid orthogonal polyline tail
          final targetLen = minPathLen + rng.nextInt(maxPathLen - minPathLen + 1);
          final path = _walkBackwards(
            head: head,
            headDir: dir,
            targetLen: targetLen,
            free: free,
            rows: rows,
            cols: cols,
            mask: silhouette.mask,
            rng: rng,
          );

          // Head run >= 2: straight segment before head
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

    // Extend tails to maximize coverage >= 92%
    _extendTails(arrows, free, occupied, rows, cols, silhouette.mask);

    return arrows;
  }

  List<GridCell> _walkBackwards({
    required GridCell head,
    required Direction headDir,
    required int targetLen,
    required Set<GridCell> free,
    required int rows,
    required int cols,
    required List<bool> mask,
    required Random rng,
  }) {
    final path = <GridCell>[head];
    final visited = <GridCell>{head};

    // First step MUST be backwards along headDir to guarantee head_run >= 2
    final second = head.shift(headDir.opposite);
    if (!second.inside(rows, cols) ||
        !mask[second.row * cols + second.col] ||
        !free.contains(second)) {
      return path; // cannot form valid head run
    }

    path.add(second);
    visited.add(second);

    var currentDir = headDir.opposite;

    while (path.length < targetLen) {
      final cur = path.last;
      final candidates = <Direction>[];

      // Prioritize straight continuation, then 90 degree turns (no 180 backtrack)
      for (final d in Direction.orthogonal) {
        if (d == currentDir.opposite) continue;
        final next = cur.shift(d);
        if (next.inside(rows, cols) &&
            mask[next.row * cols + next.col] &&
            free.contains(next) &&
            !visited.contains(next)) {
          candidates.add(d);
        }
      }

      if (candidates.isEmpty) break;

      // Prefer straight continuation (70%) over turns
      Direction chosen;
      if (candidates.contains(currentDir) && rng.nextDouble() < 0.7) {
        chosen = currentDir;
      } else {
        chosen = candidates[rng.nextInt(candidates.length)];
      }

      final nextCell = cur.shift(chosen);
      path.add(nextCell);
      visited.add(nextCell);
      currentDir = chosen;
    }

    // Return in order from tail (index 0) to head (index last)
    return path.reversed.toList();
  }

  void _extendTails(
    List<Arrow> arrows,
    Set<GridCell> free,
    Map<GridCell, String> occupied,
    int rows,
    int cols,
    List<bool> mask,
  ) {
    var grew = true;
    while (grew && free.isNotEmpty) {
      grew = false;
      for (var i = 0; i < arrows.length; i++) {
        final a = arrows[i];
        final tail = a.tail;

        for (final d in Direction.orthogonal) {
          final next = tail.shift(d);
          if (next.inside(rows, cols) &&
              mask[next.row * cols + next.col] &&
              free.contains(next)) {
            // Prepend to tail
            final newPath = [next, ...a.path];
            arrows[i] = Arrow(id: a.id, path: newPath, dir: a.dir);
            free.remove(next);
            occupied[next] = a.id;
            grew = true;
            break;
          }
        }
      }
    }
  }
}

