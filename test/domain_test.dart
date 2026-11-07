import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GridCell', () {
    test('shift moves by direction', () {
      const c = GridCell(2, 2);
      expect(c.shift(Direction.up), const GridCell(1, 2));
      expect(c.shift(Direction.down), const GridCell(3, 2));
      expect(c.shift(Direction.left), const GridCell(2, 1));
      expect(c.shift(Direction.right), const GridCell(2, 3));
    });

    test('inside bounds', () {
      expect(const GridCell(0, 0).inside(5, 5), isTrue);
      expect(const GridCell(4, 4).inside(5, 5), isTrue);
      expect(const GridCell(5, 0).inside(5, 5), isFalse);
      expect(const GridCell(0, -1).inside(5, 5), isFalse);
    });

    test('encode/decode round trip', () {
      const c = GridCell(12, 7);
      expect(GridCell.decode(c.encode()), c);
    });
  });

  group('Direction', () {
    test('opposite', () {
      expect(Direction.up.opposite, Direction.down);
      expect(Direction.left.opposite, Direction.right);
    });

    test('code round trip', () {
      for (final d in DirectionX.orthogonal) {
        expect(DirectionX.fromCode(d.code), d);
      }
    });
  });

  group('Arrow', () {
    test('encode/decode round trip', () {
      final arrow = Arrow(
        id: 'a0',
        path: const [
          GridCell(0, 0),
          GridCell(0, 1),
          GridCell(1, 1),
          GridCell(2, 1),
        ],
        dir: Direction.down,
      );
      final decoded = Arrow.decode(id: 'a0', encoded: arrow.encodePath());
      expect(decoded.path, arrow.path);
      expect(decoded.dir, arrow.dir);
    });

    test('json round trip', () {
      final arrow = Arrow(
        id: 'a7',
        path: const [GridCell(3, 4), GridCell(3, 5)],
        dir: Direction.right,
      );
      final decoded = Arrow.fromJson(arrow.toJson());
      expect(decoded, arrow);
    });
  });
}
