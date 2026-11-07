import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';
import 'package:arrow_puzzle/features/game/logic/generator/shapes.dart';

void main() {
  final s = kBuiltinShapes.first;
  print('Native baseRows: ${s.baseRows}, baseCols: ${s.baseCols}, native cells: ${s.cells.length}');
  final (minArrows, maxArrows) = DifficultyConfig.targetArrowCount(1);
  print('minArrows: $minArrows, maxArrows: $maxArrows');
  final targetN = (minArrows + maxArrows) / 2.0;
  final targetCells = targetN * 4.3;
  print('targetCells: $targetCells');
}

