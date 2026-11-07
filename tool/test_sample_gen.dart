import 'package:arrow_puzzle/features/game/logic/generator/level_generator.dart';
import 'package:arrow_puzzle/features/game/logic/generator/shapes.dart';

void main() {
  final gen = LevelGenerator();
  for (final id in [1, 5, 15, 20, 50, 100]) {
    final s = kBuiltinShapes[(id - 1) ~/ 20 % kBuiltinShapes.length];
    final res = gen.generate(id, s);
    print('L$id (${s.name}): N=${res.level.board.arrows.length}, maxFree=${res.metrics.maxFreeWave}, avgFree=${res.metrics.avgFree}, cov=${(res.metrics.coverage * 100).toStringAsFixed(1)}%, score=${res.metrics.difficultyScore}');
  }
}

