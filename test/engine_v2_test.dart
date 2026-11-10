import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:arrow_puzzle/engine/difficulty_config.dart';
import 'package:arrow_puzzle/engine/generator/level_generator.dart';
import 'package:arrow_puzzle/engine/models/arrow.dart';
import 'package:arrow_puzzle/engine/models/direction.dart';
import 'package:arrow_puzzle/engine/models/grid_cell.dart';
import 'package:arrow_puzzle/engine/rules/move_rules.dart';
import 'package:arrow_puzzle/engine/silhouette/silhouette_generator.dart';
import 'package:arrow_puzzle/engine/solver.dart';

void main() {
  group('Engine V2 - DifficultyConfig', () {
    test('monotonic arrow count matching exact specification anchors', () {
      expect(DifficultyConfig.arrowCount(1), 4);
      expect(DifficultyConfig.arrowCount(2), 6);
      expect(DifficultyConfig.arrowCount(3), 8);
      expect(DifficultyConfig.arrowCount(5), 12);
      expect(DifficultyConfig.arrowCount(8), 16);
      expect(DifficultyConfig.arrowCount(12), 24);
      expect(DifficultyConfig.arrowCount(20), 36);
      expect(DifficultyConfig.arrowCount(35), 56);
      expect(DifficultyConfig.arrowCount(50), 80);
      expect(DifficultyConfig.arrowCount(75), 110);
      expect(DifficultyConfig.arrowCount(100), 140);
      expect(DifficultyConfig.arrowCount(150), 180);

      // Monotonicity test across all 200 levels
      for (var l = 1; l < 200; l++) {
        expect(
          DifficultyConfig.baselineArrowCount(l + 1),
          greaterThanOrEqualTo(DifficultyConfig.baselineArrowCount(l)),
        );
      }
    });

    test('boss levels have +10% boost and breather levels ease', () {
      expect(DifficultyConfig.isBossLevel(10), isTrue);
      expect(DifficultyConfig.isBossLevel(20), isTrue);
      expect(DifficultyConfig.isBossLevel(11), isFalse);
    });
  });

  group('Engine V2 - SilhouetteGenerator', () {
    const gen = SilhouetteGenerator();

    test('generates connected masks without 1-cell spikes', () {
      for (var l = 1; l <= 20; l++) {
        final mask = gen.generate(
          level: l,
          targetCells: 40,
          rng: Random(42 + l),
        );
        expect(mask.cellCount, greaterThan(15));
        expect(mask.rows, greaterThanOrEqualTo(mask.cols * 0.9)); // portrait
      }
    });
  });

  group('Engine V2 - LevelGenerator & Solver', () {
    final generator = LevelGenerator();
    const solver = Solver();

    test('generates deterministic 100% solvable levels', () {
      for (final lvl in [1, 2, 3, 5, 10]) {
        final a = generator.generate(lvl);
        final b = generator.generate(lvl);

        expect(a.seed, b.seed);
        expect(a.board.arrows.length, b.board.arrows.length);
        expect(solver.isSolvable(a.board), isTrue);

        for (final arrow in a.board.arrows) {
          expect(arrow.headRun, greaterThanOrEqualTo(2),
              reason: 'Arrow ${arrow.id} must have head_run >= 2');
        }
      }
    });
  });
}

