import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/logic/move_validator.dart';
import 'package:flutter_test/flutter_test.dart';

Board _board(List<Arrow> arrows, {int rows = 5, int cols = 5}) {
  return Board(
    rows: rows,
    cols: cols,
    mask: List<bool>.filled(rows * cols, true),
    arrows: arrows,
  );
}

void main() {
  const validator = MoveValidator();

  test('exit ray runs from head to edge in arrow direction', () {
    final arrow = Arrow(
      id: 'a',
      path: const [GridCell(2, 2), GridCell(2, 3)],
      dir: Direction.right,
    );
    final board = _board([arrow]);
    final ray = board.exitRay(arrow);
    expect(ray, const [GridCell(2, 4)]);
    expect(board.cellsToExit(arrow), 2);
  });

  test('exit ray runs to the board edge', () {
    final arrow = Arrow(
      id: 'a',
      path: const [GridCell(0, 2), GridCell(0, 3)],
      dir: Direction.right,
    );
    final board = _board([arrow]);
    expect(board.exitRay(arrow), const [GridCell(0, 4)]);
    expect(board.isFree(arrow, {'a'}), isTrue);

    final edgeArrow = Arrow(
      id: 'b',
      path: const [GridCell(0, 3), GridCell(0, 4)],
      dir: Direction.right,
    );
    final board2 = _board([edgeArrow]);
    expect(board2.exitRay(edgeArrow), isEmpty);
    expect(board2.isFree(edgeArrow, {'b'}), isTrue);
  });

  test('arrow is blocked when another arrow occupies the ray', () {
    final tapped = Arrow(
      id: 'a',
      path: const [GridCell(2, 0), GridCell(2, 1)],
      dir: Direction.right,
    );
    final blocker = Arrow(
      id: 'b',
      path: const [GridCell(2, 3), GridCell(3, 3)],
      dir: Direction.down,
    );
    final board = _board([tapped, blocker]);
    final result = validator.evaluate(board, tapped, {'a', 'b'});
    expect(result.valid, isFalse);
    expect(result.blockers.map((e) => e.id), ['b']);
    expect(result.blockedRay, contains(const GridCell(2, 3)));
  });

  test('removed arrows do not block', () {
    final tapped = Arrow(
      id: 'a',
      path: const [GridCell(2, 0), GridCell(2, 1)],
      dir: Direction.right,
    );
    final blocker = Arrow(
      id: 'b',
      path: const [GridCell(2, 3), GridCell(3, 3)],
      dir: Direction.down,
    );
    final board = _board([tapped, blocker]);
    final result = validator.evaluate(board, tapped, {'a'});
    expect(result.valid, isTrue);
  });

  test('arrows crossing the ray diagonally do not block', () {
    final tapped = Arrow(
      id: 'a',
      path: const [GridCell(2, 0), GridCell(2, 1)],
      dir: Direction.right,
    );
    final other = Arrow(
      id: 'b',
      path: const [GridCell(1, 3), GridCell(1, 4)],
      dir: Direction.down,
    );
    final board = _board([tapped, other]);
    expect(tapped.head, const GridCell(2, 1));
    final result = validator.evaluate(board, tapped, {'a', 'b'});
    expect(result.valid, isTrue);
  });
}
