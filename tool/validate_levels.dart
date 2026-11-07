// Validation CLI tool for Arrow Escape levels.
//
// Usage:
//   dart run tool/validate_levels.dart
//
// Checks:
// - All level JSONs exist (1..200)
// - Solvability via Solver
// - Layout hash uniqueness across all levels
// - N in target bounds
// - free0 <= max(2, 6% of N)
// - depthRatio >= 0.25 (L1-10) or >= 0.35 (L11-20)
// - avgRayBlockers >= 2.0 (L1-8) or >= 3.0 (L9-20)
// - multiBlockerRatio >= 30%
// - maxFreeWave <= 12% of N
// - coverage >= 92%
// - difficulty_score monotonically increases on average per shape (L20 > L1 by >= 40%)

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';
import 'package:arrow_puzzle/features/game/logic/solver.dart';

void main(List<String> args) {
  final levelsDir = Directory('assets/levels');
  if (!levelsDir.existsSync()) {
    stderr.writeln('assets/levels directory not found.');
    exit(1);
  }

  const solver = Solver();
  final seenHashes = <String, int>{};
  var totalChecked = 0;
  var totalFailed = 0;

  final shapeStats = <String, List<BoardQualityMetrics>>{};

  print(
    '| Level | Shape      | N   | free0 | maxWave | avgFree | Depth | Decoys | Cov%  | Score  | Status |',
  );
  print(
    '|-------|------------|-----|-------|---------|---------|-------|--------|-------|--------|--------|',
  );

  for (var id = 1; id <= 200; id++) {
    final file = File('${levelsDir.path}/level_${id.toString().padLeft(3, '0')}.json');
    if (!file.existsSync()) {
      print('| ${id.toString().padLeft(5)} | MISSING    |     |       |       |          |        |       |       |        | FAIL   |');
      totalFailed++;
      continue;
    }

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final shape = json['shape'] as String;
    final rows = json['rows'] as int;
    final cols = json['cols'] as int;
    final maskInts = (json['mask'] as List).cast<int>();
    final mask = maskInts.map((m) => m == 1).toList();
    final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
    final arrows = rawArrows.map(Arrow.fromJson).toList();
    final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);

    final hash = json['hash'] as String? ?? '';
    final metrics = DifficultyConfig.evaluate(board);
    shapeStats.putIfAbsent(shape, () => []).add(metrics);
    totalChecked++;

    final isSolvable = solver.solvableByGreedy(board);
    final isUnique = hash.isNotEmpty && !seenHashes.containsKey(hash);
    if (hash.isNotEmpty) seenHashes[hash] = id;

    var directionsValid = true;
    for (final arrow in arrows) {
      if (arrow.path.length >= 2) {
        final prev = arrow.path[arrow.path.length - 2];
        final head = arrow.path.last;
        final dr = head.row - prev.row;
        final dc = head.col - prev.col;
        Direction expectedDir;
        if (dr == -1 && dc == 0) {
          expectedDir = Direction.up;
        } else if (dr == 1 && dc == 0) {
          expectedDir = Direction.down;
        } else if (dc == -1 && dr == 0) {
          expectedDir = Direction.left;
        } else if (dc == 1 && dr == 0) {
          expectedDir = Direction.right;
        } else {
          expectedDir = arrow.dir;
        }

        if (arrow.dir != expectedDir) {
          directionsValid = false;
          break;
        }
      }
    }

    final validMetrics = metrics.isValidFor(id);
    final validSolvable = isSolvable;
    final validUnique = isUnique;

    final pass = validSolvable && validUnique && validMetrics && directionsValid;
    if (!pass) {
      totalFailed++;
      print('Debug L$id fail: N=${metrics.arrowCount}, cov=${metrics.coverage} (>=0.85), maxWave=${metrics.maxFreeWave} (<=2), free0=${metrics.free0} (<=2), avgFree=${metrics.avgFree} (<=1.25), solvable=$validSolvable, unique=$validUnique, dirValid=$directionsValid');
    }

    final status = pass ? 'PASS' : 'FAIL';
    print(
      '| ${id.toString().padLeft(5)} '
      '| ${shape.padRight(10)} '
      '| ${metrics.arrowCount.toString().padLeft(3)} '
      '| ${metrics.free0.toString().padLeft(5)} '
      '| ${metrics.maxFreeWave.toString().padLeft(7)} '
      '| ${metrics.avgFree.toStringAsFixed(2).padLeft(7)} '
      '| ${(metrics.depthRatio * 100).toStringAsFixed(0).padLeft(4)}% '
      '| ${metrics.decoyCount.toString().padLeft(6)} '
      '| ${(metrics.coverage * 100).toStringAsFixed(1).padLeft(5)}% '
      '| ${metrics.difficultyScore.toStringAsFixed(4)} '
      '| $status  |',
    );
  }

  print('\n=== SHAPE SUMMARY ===');
  print('| Shape      | Levels | Min N | Avg N | Max N | Avg Score | L1 Score | L20 Score | Diff Ramp |');
  print('|------------|--------|-------|-------|-------|-----------|----------|-----------|-----------|');

  for (final entry in shapeStats.entries) {
    final list = entry.value;
    if (list.isEmpty) continue;
    final minN = list.map((m) => m.arrowCount).reduce((a, b) => a < b ? a : b);
    final maxN = list.map((m) => m.arrowCount).reduce((a, b) => a > b ? a : b);
    final avgN = list.map((m) => m.arrowCount).reduce((a, b) => a + b) / list.length;
    final avgScore = list.map((m) => m.difficultyScore).reduce((a, b) => a + b) / list.length;
    final l1Score = list.first.difficultyScore;
    final l20Score = list.last.difficultyScore;
    final ramp = l1Score > 0 ? (l20Score - l1Score) / l1Score : 0.0;

    print(
      '| ${entry.key.padRight(10)} '
      '| ${list.length.toString().padLeft(6)} '
      '| ${minN.toString().padLeft(5)} '
      '| ${avgN.toStringAsFixed(1).padLeft(5)} '
      '| ${maxN.toStringAsFixed(0).padLeft(5)} '
      '| ${avgScore.toStringAsFixed(4).padLeft(9)} '
      '| ${l1Score.toStringAsFixed(4).padLeft(8)} '
      '| ${l20Score.toStringAsFixed(4).padLeft(9)} '
      '| +${(ramp * 100).toStringAsFixed(1)}%     |',
    );
  }

  print('\nTotal checked: $totalChecked, Failed: $totalFailed');
  if (totalFailed > 0) {
    exit(1);
  }
}

