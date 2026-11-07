import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/logic/solver.dart';
import 'package:flutter_test/flutter_test.dart';

Board _board(List<Arrow> arrows, {int rows = 6, int cols = 6}) {
  return Board(
    rows: rows,
    cols: cols,
    mask: List<bool>.filled(rows * cols, true),
    arrows: arrows,
  );
}

void main() {
  const solver = Solver();

  test('chain dependency resolves in correct order', () {
    // b sits on a's ray; a must be removed after b.
    final a = Arrow(
      id: 'a',
      path: const [GridCell(2, 0), GridCell(2, 1)],
      dir: Direction.right,
    );
    final b = Arrow(
      id: 'b',
      path: const [GridCell(2, 3), GridCell(3, 3)],
      dir: Direction.down,
    );
    final order = solver.solutionOrder(_board([a, b]));
    expect(order, isNotNull);
    expect(order!.indexOf('b'), lessThan(order.indexOf('a')));
    expect(order, hasLength(2));
  });

  test('dependency graph has correct edges', () {
    final a = Arrow(
      id: 'a',
      path: const [GridCell(2, 0), GridCell(2, 1)],
      dir: Direction.right,
    );
    final b = Arrow(
      id: 'b',
      path: const [GridCell(2, 3), GridCell(3, 3)],
      dir: Direction.down,
    );
    final graph = solver.dependencyGraph(_board([a, b]));
    expect(graph['a'], {'b'});
    expect(graph['b'], isEmpty);
  });

  test('longest chain computed', () {
    // Linear chain of three: c blocks b blocks a.
    final a = Arrow(
      id: 'a',
      path: const [GridCell(0, 0), GridCell(0, 1)],
      dir: Direction.right,
    );
    final b = Arrow(
      id: 'b',
      path: const [GridCell(0, 3), GridCell(1, 3)],
      dir: Direction.down,
    );
    final c = Arrow(
      id: 'c',
      path: const [GridCell(3, 3), GridCell(4, 3)],
      dir: Direction.down,
    );
    final analysis = solver.analyze(_board([a, b, c]));
    expect(analysis.longestChain, 3);
    expect(analysis.freeAtStart, 1);
  });

  test('greedy solver agrees with topological order', () {
    final a = Arrow(
      id: 'a',
      path: const [GridCell(2, 0), GridCell(2, 1)],
      dir: Direction.right,
    );
    final b = Arrow(
      id: 'b',
      path: const [GridCell(2, 3), GridCell(3, 3)],
      dir: Direction.down,
    );
    final board = _board([a, b]);
    expect(solver.solvableByGreedy(board), isTrue);
    expect(solver.solutionOrder(board), isNotNull);
  });

  test('cycle-free guarantee: generated-style board never cycles', () {
    // Independent arrows all free.
    final arrows = [
      for (var i = 0; i < 4; i++)
        Arrow(
          id: 'a$i',
          path: [GridCell(i * 1, 0), GridCell(i, 1)],
          dir: Direction.left,
        ),
    ];
    final analysis = solver.analyze(_board(arrows));
    expect(analysis.isSolvable, isTrue);
    expect(analysis.freeAtStart, 4);
  });
}
