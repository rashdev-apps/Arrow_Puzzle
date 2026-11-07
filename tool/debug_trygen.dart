import 'dart:math';
import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';
import 'package:arrow_puzzle/features/game/logic/generator/level_generator.dart';
import 'package:arrow_puzzle/features/game/logic/generator/shapes.dart';

void main() {
  final gen = LevelGenerator();
  final s = kBuiltinShapes.first;
  final (minArrows, maxArrows) = DifficultyConfig.targetArrowCount(1);
  final targetN = (minArrows + maxArrows) / 2.0;
  final targetCells = targetN * 4.3;
  final scale = sqrt(targetCells / s.cells.length);
  final scaled = s.resized((s.baseRows * scale).round(), (s.baseCols * scale).round());
  print('Scaled: ${scaled.baseRows}x${scaled.baseCols}, masked cells: ${scaled.cells.length}');

  final rng = Random(42);
  // Test building spine chain directly
  for (var i = 0; i < 5; i++) {
    final res = (gen as dynamic)._tryGenerate(
      1,
      s.name,
      scaled.baseRows,
      scaled.baseCols,
      scaled.toMask(),
      minArrows,
      maxArrows,
      rng,
    );
    print('Attempt $i result: $res');
  }
}

