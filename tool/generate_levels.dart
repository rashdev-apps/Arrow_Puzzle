import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';
import 'package:arrow_puzzle/features/game/logic/generator/level_generator.dart';

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
  final seenHashes = <String, int>{};
  var failures = 0;

  stdout.writeln('Generating $count linear rectangular levels (1..$count)...');

  for (var id = 1; id <= count; id++) {
    var saltBump = 0;
    GeneratedLevel result;
    while (true) {
      final salt = saltBump == 0 ? 'arrowescape' : 'arrowescape#$saltBump';
      result = generator.generate(id, salt: salt);
      final clash = seenHashes[result.level.hash];
      if (clash == null) {
        seenHashes[result.level.hash] = id;
        break;
      }
      saltBump++;
    }

    final m = result.metrics;
    final file = File('${levelsDir.path}/level_${id.toString().padLeft(3, '0')}.json');
    file.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(result.level.toJson()),
    );

    final isBoss = DifficultyConfig.isBossLevel(id);
    final bossMark = isBoss ? ' [BOSS]' : '';
    stdout.writeln(
      'L${id.toString().padLeft(3, '0')}: N=${m.arrowCount.toString().padLeft(3)} '
      'grid=${result.level.rows}x${result.level.cols} cov=${(m.coverage * 100).toStringAsFixed(1)}% '
      'free0=${m.free0} maxFreeWave=${m.maxFreeWave} score=${m.difficultyScore.toStringAsFixed(1)}$bossMark',
    );
  }

  stdout.writeln('Done. Generated $count levels ($failures retries).');
}
