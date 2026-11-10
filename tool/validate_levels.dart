import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/engine/difficulty_config.dart';
import 'package:arrow_puzzle/engine/metrics/puzzle_metrics.dart';
import 'package:arrow_puzzle/engine/models/level.dart';
import 'package:arrow_puzzle/engine/solver.dart';

void main() {
  final dir = Directory('assets/levels');
  if (!dir.existsSync()) {
    stderr.writeln('Error: assets/levels directory not found.');
    exit(1);
  }

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  stdout.writeln('Validating ${files.length} levels against V2 rules...');

  const solver = Solver();
  var failed = 0;

  for (final f in files) {
    final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final level = Level.fromJson(raw);
    final m = PuzzleQualityMetrics.evaluate(level.board, solver: solver);

    if (!m.isSolvable) {
      stderr.writeln('FAIL: Level ${level.id} is unsolvable!');
      failed++;
      continue;
    }

    if (level.arrowCount < 4) {
      stderr.writeln('FAIL: Level ${level.id} has fewer than 4 arrows');
      failed++;
      continue;
    }

    for (final a in level.board.arrows) {
      if (a.headRun < 2) {
        stderr.writeln('FAIL: Level ${level.id} arrow ${a.id} headRun < 2');
        failed++;
        break;
      }
    }
  }

  if (failed > 0) {
    stderr.writeln('Validation failed with $failed errors.');
    exit(1);
  } else {
    stdout.writeln('ALL ${files.length} LEVELS PASSED VALIDATION! Solvability 100%.');
  }
}
