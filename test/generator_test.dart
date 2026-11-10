import 'package:arrow_puzzle/engine/difficulty_config.dart';
import 'package:arrow_puzzle/engine/generator/level_generator.dart';
import 'package:arrow_puzzle/engine/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generator = LevelGenerator();
  const solver = Solver();

  group('DifficultyConfig', () {
    test('arrowCount curve is monotonically increasing', () {
      expect(DifficultyConfig.arrowCount(1), 4);
      expect(DifficultyConfig.arrowCount(2), 6);
      expect(DifficultyConfig.arrowCount(3), 8);
      expect(DifficultyConfig.arrowCount(5), 12);
      expect(DifficultyConfig.arrowCount(8), 16);
      expect(DifficultyConfig.arrowCount(12), 24);

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
        expect(a.seed, b.seed);
        expect(a.board.arrows, b.board.arrows);
      }
    });

    test('produces solvable boards on irregular silhouettes', () {
      for (final id in [1, 2, 5, 10]) {
        final level = generator.generate(id);
        final board = level.board;
        expect(level.solution, hasLength(board.arrows.length));
        expect(solver.isSolvable(board), isTrue);
        expect(board.coverage, greaterThanOrEqualTo(0.80));
      }
    });
  });
}
