import 'package:arrow_puzzle/features/game/logic/generator/layout_hash.dart';
import 'package:arrow_puzzle/features/game/logic/generator/level_generator.dart';
import 'package:arrow_puzzle/features/game/logic/generator/shapes.dart';
import 'package:arrow_puzzle/features/game/logic/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generator = LevelGenerator();
  const solver = Solver();

  group('LevelGenerator', () {
    test('is deterministic per level id', () {
      for (final id in [1, 25, 80, 150, 200]) {
        final shape = kBuiltinShapes[(id - 1) ~/ 20 % kBuiltinShapes.length];
        final a = generator.generate(id, shape);
        final b = generator.generate(id, shape);
        expect(a.level.hash, b.level.hash);
        expect(a.level.board.arrows, b.level.board.arrows);
      }
    });

    test('produces solvable, non-trivial boards across all shapes', () {
      for (final shape in kBuiltinShapes) {
        for (final id in [15, 60, 140, 190]) {
          final result = generator.generate(id, shape);
          final board = result.level.board;
          expect(result.solutionOrder, hasLength(board.arrows.length));
          expect(solver.solvableByGreedy(board), isTrue);
          expect(result.coverage, greaterThanOrEqualTo(0.85));
          // Every arrow stays inside the mask.
          for (final arrow in board.arrows) {
            for (final cell in arrow.path) {
              expect(board.isMasked(cell), isTrue,
                  reason: '$shape level $id arrow ${arrow.id} at $cell');
            }
          }
        }
      }
    });

    test('every generated level of a tier set has a unique layout hash', () {
      final hashes = <String>{};
      for (var id = 1; id <= 60; id++) {
        final shape = kBuiltinShapes[(id - 1) ~/ 20 % kBuiltinShapes.length];
        final result = generator.generate(id, shape);
        expect(hashes.add(result.level.hash), isTrue,
            reason: 'duplicate layout hash at level $id');
      }
    });

    test('intro levels are accessible but dense', () {
      final result = generator.generate(1, kBuiltinShapes.first);
      expect(result.level.board.rows, greaterThanOrEqualTo(10));
      expect(result.level.board.arrows.length, greaterThanOrEqualTo(20));
    });

    test('hard tiers use large boards with deep chains', () {
      final result = generator.generate(180, kBuiltinShapes[0]);
      expect(result.level.board.rows, greaterThanOrEqualTo(14));
      expect(result.longestChain, greaterThan(1));
    });

    test('difficulty metadata is populated', () {
      final result = generator.generate(42, kBuiltinShapes[1]);
      expect(result.level.difficulty, greaterThan(0));
      expect(result.level.parMoves, result.level.arrowCount);
    });
  });

  group('LayoutHash', () {
    test('seed is deterministic', () {
      expect(LayoutHash.seed('arrowpuzzle:42'),
          LayoutHash.seed('arrowpuzzle:42'));
      expect(LayoutHash.seed('arrowpuzzle:42'),
          isNot(LayoutHash.seed('arrowpuzzle:43')));
    });
  });
}
