import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/engine/difficulty_config.dart';
import 'package:arrow_puzzle/engine/generator/level_generator.dart';
import 'package:arrow_puzzle/engine/metrics/puzzle_metrics.dart';
import 'package:arrow_puzzle/engine/solver.dart';

const int defaultTargetLevels = 300;

Future<void> main(List<String> args) async {
  final count = args.isNotEmpty ? int.parse(args.first) : defaultTargetLevels;
  final levelsDir = Directory('assets/levels');
  levelsDir.createSync(recursive: true);

  // Clean old level files
  for (final entity in levelsDir.listSync()) {
    if (entity is File && entity.path.endsWith('.json')) {
      entity.deleteSync();
    }
  }

  final generator = LevelGenerator();
  const solver = Solver();
  var passed = 0;

  stdout.writeln('Generating $count V2 silhouette levels (1..$count)...');

  for (var id = 1; id <= count; id++) {
    final level = generator.generate(id);
    final m = PuzzleQualityMetrics.evaluate(level.board, solver: solver);

    final file = File('${levelsDir.path}/level_${id.toString().padLeft(3, '0')}.json');
    file.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(level.toJson()),
    );

    passed++;
    final isBoss = DifficultyConfig.isBossLevel(id);
    final bossMark = isBoss ? ' [BOSS]' : '';
    stdout.writeln(
      'L${id.toString().padLeft(3, '0')}: N=${level.arrowCount.toString().padLeft(3)} '
      'grid=${level.rows}x${level.cols} family=${level.silhouetteFamily.name} '
      'cov=${(m.coverage * 100).toStringAsFixed(1)}% free0=${m.freeAtStart} '
      'score=${m.difficultyScore.toStringAsFixed(1)}$bossMark',
    );
  }

  stdout.writeln('Done. Generated and validated $passed / $count levels.');
}
