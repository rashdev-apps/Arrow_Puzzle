import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';
import 'package:arrow_puzzle/features/game/logic/generator/level_generator.dart';
import 'package:arrow_puzzle/features/game/logic/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generator = LevelGenerator();
  const solver = Solver();

  group('DifficultyConfig', () {
    test('arrowCount curve is monotonically increasing', () {
      expect(DifficultyConfig.arrowCount(1), 4);
      expect(DifficultyConfig.arrowCount(2), 8);
      expect(DifficultyConfig.arrowCount(3), 12);
      expect(DifficultyConfig.arrowCount(4), 16);
      expect(DifficultyConfig.arrowCount(5), 20);

      // Monotonic baseline progression
      for (var l = 1; l < 100; l++) {
        expect(DifficultyConfig.baselineArrowCount(l + 1),
            greaterThanOrEqualTo(DifficultyConfig.baselineArrowCount(l)));
      }
    });

    test('boss levels have sawtooth boost and breathe', () {
      expect(DifficultyConfig.isBossLevel(10), isTrue);
      expect(DifficultyConfig.isBossLevel(20), isTrue);
      expect(DifficultyConfig.isBossLevel(11), isFalse);
    });
  });

  group('LevelGenerator', () {
    test('is deterministic per level id', () {
      for (final id in [1, 5, 10, 25]) {
        final a = generator.generate(id);
        final b = generator.generate(id);
        expect(a.level.hash, b.level.hash);
        expect(a.level.board.arrows, b.level.board.arrows);
      }
    });

    test('produces solvable boards on rectangular grids', () {
      for (final id in [1, 2, 5, 10]) {
        final result = generator.generate(id);
        final board = result.level.board;
        expect(result.solutionOrder, hasLength(board.arrows.length));
        expect(solver.solvableByGreedy(board), isTrue);
        expect(result.coverage, greaterThanOrEqualTo(0.80));
      }
    });
  });
}
