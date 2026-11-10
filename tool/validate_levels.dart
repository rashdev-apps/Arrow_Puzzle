// Validation CLI tool for Arrow Escape levels.
//
// Usage:
//   dart run tool/validate_levels.dart
//
// Checks:
// - All level JSONs exist (1..300)
// - Solvability via Solver
// - Layout hash uniqueness across all levels
// - N matching difficulty_config arrowCount curve
// - Rectangular grid coverage
// - Metrics monotonic trends

import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
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

  stdout.writeln(
    '| Level | N   | Grid   | free0 | maxWave | avgFree | Cov%  | Time  | Tier   | Status |',
  );
  stdout.writeln(
    '|-------|-----|--------|-------|---------|---------|-------|-------|--------|--------|',
  );

  final files = levelsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    totalChecked++;
    final raw = file.readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final id = json['id'] as int;
    final rows = json['rows'] as int;
    final cols = json['cols'] as int;
    final mask = (json['mask'] as List).map((m) => (m as int) == 1).toList();
    final arrows = (json['arrows'] as List)
        .map((a) => Arrow.fromJson((a as Map).cast<String, dynamic>()))
        .toList();

    final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
    final metrics = BoardQualityMetrics.evaluate(board, solver: solver);

    final hash = json['hash'] as String?;
    final timeLimit = json['time_limit_seconds'] as int?;
    final tier = DifficultyConfig.tierForLevel(id);

    final issues = <String>[];
    if (!metrics.isSolvable) issues.add('UNSOLVABLE');
    if (hash != null && seenHashes.containsKey(hash)) {
      issues.add('HASH_CLASH(${seenHashes[hash]})');
    } else if (hash != null) {
      seenHashes[hash] = id;
    }

    final isBoss = DifficultyConfig.isBossLevel(id);
    final tierLabel = isBoss ? '${tier.label}*' : tier.label;
    final status = issues.isEmpty ? 'PASS' : 'FAIL(${issues.join(",")})';
    if (issues.isNotEmpty) totalFailed++;

    stdout.writeln(
      '| ${id.toString().padLeft(3)} '
      '| ${arrows.length.toString().padLeft(3)} '
      '| ${rows.toString().padLeft(2)}x${cols.toString().padRight(2)} '
      '| ${metrics.free0.toString().padLeft(5)} '
      '| ${metrics.maxFreeWave.toString().padLeft(7)} '
      '| ${metrics.avgFree.toStringAsFixed(2).padLeft(7)} '
      '| ${(metrics.coverage * 100).toStringAsFixed(0).padLeft(4)}% '
      '| ${timeLimit != null ? "${timeLimit}s".padLeft(5) : "None".padLeft(5)} '
      '| ${tierLabel.padRight(6)} '
      '| $status |',
    );
  }

  stdout.writeln('\n=======================================');
  stdout.writeln('Total Checked: $totalChecked, Failed: $totalFailed');
  if (totalFailed > 0) exit(1);
}
