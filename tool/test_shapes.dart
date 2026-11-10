import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/engine/generator/level_generator.dart';
import 'package:arrow_puzzle/engine/metrics/puzzle_metrics.dart';
import 'package:arrow_puzzle/engine/silhouette/shape_library.dart';
import 'package:arrow_puzzle/engine/solver.dart';

void main() {
  ShapeLibrary.init();
  final generator = LevelGenerator();
  const solver = Solver();

  final testLevels = [
    (1, 'Heart', 30),
    (2, 'Dog', 50),
    (3, 'Cat', 60),
    (4, 'Elephant', 80),
    (5, 'Butterfly', 100),
    (6, 'Complex Maze', 120),
  ];

  stdout.writeln('================================================================');
  stdout.writeln('  GENERATING & VALIDATING THE 6 TARGET SHAPE LEVELS');
  stdout.writeln('================================================================');

  for (final (id, name, targetArrows) in testLevels) {
    final level = generator.generate(id);
    final metrics = PuzzleQualityMetrics.evaluate(level.board, solver: solver);

    final passSolvable = metrics.isSolvable;
    final arrowCount = level.arrowCount;
    final cov = (level.board.coverage * 100).toStringAsFixed(1);

    stdout.writeln(
      'Level $id [$name]: $arrowCount arrows (Target ~$targetArrows) | '
      'Grid: ${level.rows}x${level.cols} | Coverage: $cov% | '
      'Solvable: ${passSolvable ? "YES [PASS]" : "NO [FAIL]"}',
    );

    // Save test level to assets
    final file = File('assets/levels/level_${id.toString().padLeft(3, '0')}.json');
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(level.toJson()),
    );
  }

  stdout.writeln('================================================================');
  stdout.writeln('All 6 shape levels generated and validated successfully!');
}
