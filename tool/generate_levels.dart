// Pre-generates the 200 launch levels into assets/levels/.
//
// Usage (from the project root):
//   dart run tool/generate_levels.dart
//
// Every level is deterministic: level N uses seed hash('arrowpuzzle', N).
// If a generated layout hash collides with an earlier level, the salt is
// bumped and generation retried, keeping output stable across machines.

import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/features/game/logic/generator/level_generator.dart';
import 'package:arrow_puzzle/features/game/logic/generator/shapes.dart';

const int maxLevel = 200;
const int chapterSize = 20;

Future<void> main(List<String> args) async {
  final count = args.isNotEmpty ? int.parse(args.first) : maxLevel;
  final levelsDir = Directory('assets/levels');
  final shapesDir = Directory('assets/shapes');
  levelsDir.createSync(recursive: true);
  shapesDir.createSync(recursive: true);

  // Ship each built-in shape as a JSON asset so new shapes can be added
  // by dropping files into assets/shapes/ without touching code.
  for (final shape in kBuiltinShapes) {
    File('${shapesDir.path}/${shape.name}.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'name': shape.name,
        'rows': shape.art,
      }),
    );
  }

  final generator = LevelGenerator();
  final seenHashes = <String, int>{};
  var failures = 0;

  for (var id = 1; id <= count; id++) {
    final chapter = (id - 1) ~/ chapterSize;
    final shape = kBuiltinShapes[chapter % kBuiltinShapes.length];

    var saltBump = 0;
    GeneratedLevel result;
    while (true) {
      final salt = saltBump == 0 ? 'arrowescape' : 'arrowescape#$saltBump';
      result = generator.generate(id, shape, salt: salt);
      final clash = seenHashes[result.level.hash];
      if (clash == null) break;
      saltBump++;
      if (saltBump > 20) {
        throw StateError(
          'Could not find unique layout for level $id (clash with $clash)',
        );
      }
    }

    seenHashes[result.level.hash] = id;
    File('${levelsDir.path}/level_${id.toString().padLeft(3, '0')}.json')
        .writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(result.level.toJson()),
    );

    stdout.writeln(
      'Level $id (${shape.name}) ${result.level.board.rows}x'
      '${result.level.board.cols}, ${result.level.arrowCount} arrows, '
      'coverage ${(result.coverage * 100).toStringAsFixed(0)}%, '
      'chain ${result.longestChain}, free ${result.freeAtStart}, '
      'maxWave ${result.metrics.maxFreeWave}, avgFree ${result.metrics.avgFree}, '
      'difficulty ${result.level.difficulty}, hash ${result.level.hash}',
    );
  }

  // Manifest with chapter metadata for the level-select screen.
  final chapters = <Map<String, dynamic>>[];
  for (var c = 0; c * chapterSize < count; c++) {
    final shape = kBuiltinShapes[c % kBuiltinShapes.length];
    chapters.add({
      'index': c,
      'name': _chapterName(shape.name),
      'shape': shape.name,
      'firstLevel': c * chapterSize + 1,
    });
  }
  File('${levelsDir.path}/manifest.json').writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'count': count,
      'seedScheme': 'fnv1a64("arrowpuzzle:<levelId>")',
      'chapters': chapters,
    }),
  );

  stdout.writeln('Done. $count levels generated, $failures failures.');
}

String _chapterName(String shapeName) =>
    '${shapeName[0].toUpperCase()}${shapeName.substring(1)} Shapes';
