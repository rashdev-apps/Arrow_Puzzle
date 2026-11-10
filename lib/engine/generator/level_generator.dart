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
import '../silhouette/shape_library.dart';
import '../silhouette/shape_rasterizer.dart';
import '../silhouette/silhouette_mask.dart';
import '../solver.dart';

class LevelGenerator {
  final ShapeRasterizer _rasterizer = const ShapeRasterizer();
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
    final shape = ShapeLibrary.templateForLevel(levelId);

    // Compute grid dimensions suited for recognizable silhouette resolution
    // Higher arrow counts require larger grid resolution so animals/shapes are detailed
    final (rows, cols) = _calculateGridResolution(targetArrows);

    // Step 2 & 3: Rasterize vector silhouette to 2D occupancy grid
    final silhouette = _rasterizer.rasterize(
      shape: shape,
      rows: rows,
      cols: cols,
    );

    // Step 4 to 8: Chain puzzle generation along silhouette contours
    final arrows = _generateContourArrows(
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

  (int, int) _calculateGridResolution(int targetArrows) {
    // Calibrate grid cells so silhouette is clear and arrows have room to wind
    final avgPathLen = targetArrows <= 40 ? 2.6 : (targetArrows <= 90 ? 3.0 : 3.4);
    final neededCells = (targetArrows * avgPathLen / 0.88).ceil();

    // Portrait aspect ratio ~ 1.25 to 1.4
    var cols = (sqrt(neededCells) * 0.85).floor().clamp(10, 40);
    var rows = (neededCells / cols).ceil().clamp(cols, 55);

    return (rows, cols);
  }

  List<Arrow> _generateContourArrows({
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

    final minPathLen = targetArrows <= 40 ? 2 : 3;
    final maxPathLen = targetArrows <= 40 ? 3 : (targetArrows <= 100 ? 5 : 7);

    var attempts = 0;
    while (arrows.length < targetArrows && free.isNotEmpty && attempts < 4000) {
      attempts++;
      final starts = free.toList()..shuffle(rng);
      Arrow? best;

      for (final head in starts) {
        if (best != null) break;
        final dirs = [...Direction.orthogonal]..shuffle(rng);

        for (final dir in dirs) {
          // Check ray exit to boundary
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

          // Head run >= 2: first segment must be opposite to dir
          final opp = dir.opposite;
          final second = head.shift(opp);
          if (!second.inside(rows, cols) ||
              !silhouette.mask[second.row * cols + second.col] ||
              !free.contains(second)) {
            continue;
          }

          final targetLen = minPathLen + rng.nextInt(maxPathLen - minPathLen + 1);
          final path = _walkPolyline(
            head: head,
            headDir: dir,
            targetLen: targetLen,
            free: free,
            rows: rows,
            cols: cols,
            mask: silhouette.mask,
            rng: rng,
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

    // Extend tails to maximize coverage and form complete recognizable shape
    _extendTails(arrows, free, occupied, rows, cols, silhouette.mask);

    return arrows;
  }

  List<GridCell> _walkPolyline({
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

    final second = head.shift(headDir.opposite);
    path.add(second);
    visited.add(second);

    var currentDir = headDir.opposite;

    while (path.length < targetLen) {
      final cur = path.last;
      final candidates = <Direction>[];

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

      // Follow shape contour with 65% straight continuation
      Direction chosen;
      if (candidates.contains(currentDir) && rng.nextDouble() < 0.65) {
        chosen = currentDir;
      } else {
        chosen = candidates[rng.nextInt(candidates.length)];
      }

      final nextCell = cur.shift(chosen);
      path.add(nextCell);
      visited.add(nextCell);
      currentDir = chosen;
    }

    // Tail to head ordering
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
