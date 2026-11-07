import 'dart:math';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';

void main() {
  final rng = Random(42);
  final free = {for (var r = 0; r < 10; r++) for (var c = 0; c < 10; c++) GridCell(r, c)};
  final head = GridCell(5, 5);
  final dir = Direction.up;
  final path = walkBackwards(head, dir, 4, free, rng);
  print('dir: $dir');
  print('path: $path');
  print('path.first: ${path.first}, path.last: ${path.last}');
  print('segment from path[path.length - 2] to path.last:');
  final prev = path[path.length - 2];
  final last = path.last;
  print('prev: $prev, last: $last');
  final dr = last.row - prev.row;
  final dc = last.col - prev.col;
  print('dr: $dr, dc: $dc');
}

List<GridCell> walkBackwards(GridCell head, Direction forwardDir, int targetLen, Set<GridCell> free, Random rng) {
  final backwardsDir = forwardDir.opposite;
  final path = <GridCell>[head];
  final claimed = <GridCell>{head};
  var current = head;
  var currentBackDir = backwardsDir;
  while (path.length < targetLen) {
    final candidates = [currentBackDir, turnLeft(currentBackDir), turnRight(currentBackDir)]..shuffle(rng);
    GridCell? next;
    Direction? chosenDir;
    for (final d in candidates) {
      final step = current.shift(d);
      if (free.contains(step) && !claimed.contains(step)) {
        next = step;
        chosenDir = d;
        break;
      }
    }
    if (next == null) break;
    path.add(next);
    claimed.add(next);
    current = next;
    currentBackDir = chosenDir!;
  }
  return path.reversed.toList();
}

Direction turnLeft(Direction d) => switch (d) {
  Direction.up => Direction.left,
  Direction.left => Direction.down,
  Direction.down => Direction.right,
  Direction.right => Direction.up,
};

Direction turnRight(Direction d) => switch (d) {
  Direction.up => Direction.right,
  Direction.right => Direction.down,
  Direction.down => Direction.left,
  Direction.left => Direction.up,
};

