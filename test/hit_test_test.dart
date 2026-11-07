import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/logic/hit_test.dart' as ht;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cell = 40.0;
  const tester = ht.HitTester(tolerance: 14);

  Arrow elbow() => Arrow(
        id: 'a',
        path: const [GridCell(1, 1), GridCell(1, 3), GridCell(3, 3)],
        dir: Direction.down,
      );

  test('taps near a segment hit the arrow', () {
    // Horizontal segment from (1,1) to (1,3): centre y = 60, x in [60,140].
    final hit = tester.hit([elbow()], const Offset(100, 64), cell);
    expect(hit?.id, 'a');
  });

  test('taps on the vertical segment hit too', () {
    // Vertical segment x = 140, y in [60,140].
    final hit = tester.hit([elbow()], const Offset(137, 100), cell);
    expect(hit?.id, 'a');
  });

  test('taps far from any segment miss', () {
    expect(tester.hit([elbow()], const Offset(20, 20), cell), isNull);
    expect(tester.hit([elbow()], Offset(100, 64 + 15.1), cell), isNull);
  });

  test('taps beyond tolerance do not hit', () {
    final hit = tester.hit([elbow()], const Offset(100, 80), cell);
    expect(hit, isNull);
  });

  test('overlapping arrows prefer the shortest one', () {
    final long = Arrow(
      id: 'long',
      path: const [
        GridCell(0, 0),
        GridCell(0, 1),
        GridCell(0, 2),
        GridCell(0, 3),
        GridCell(0, 4),
        GridCell(0, 5),
      ],
      dir: Direction.right,
    );
    final short = Arrow(
      id: 'short',
      path: const [GridCell(0, 2), GridCell(0, 3)],
      dir: Direction.right,
    );
    final hit = tester.hit([long, short], const Offset(110, 22), cell);
    expect(hit?.id, 'short');
  });

  test('single-cell arrow is hittable', () {
    final tiny = Arrow(
      id: 'tiny',
      path: const [GridCell(2, 2)],
      dir: Direction.up,
    );
    final hit = tester.hit([tiny], const Offset(103, 98), cell);
    expect(hit?.id, 'tiny');
  });

  test('segmentDistance maths', () {
    expect(ht.BoardGeometry.segmentDistance(
      const Offset(5, 5),
      Offset.zero,
      const Offset(10, 0),
    ), 5);
    expect(ht.BoardGeometry.segmentDistance(
      const Offset(-4, 3),
      Offset.zero,
      const Offset(10, 0),
    ), 5);
  });
}
