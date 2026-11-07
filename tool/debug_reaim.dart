import 'dart:math';
import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';
import 'package:arrow_puzzle/features/game/logic/generator/shapes.dart';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/logic/solver.dart';

void main() {
  final s = kBuiltinShapes.first;
  final (minArrows, maxArrows) = DifficultyConfig.targetArrowCount(1);
  final targetN = (minArrows + maxArrows) / 2.0;
  final targetCells = targetN * 4.3;
  final scale = sqrt(targetCells / s.cells.length);
  final scaled = s.resized((s.baseRows * scale).round(), (s.baseCols * scale).round());
  final rows = scaled.baseRows;
  final cols = scaled.baseCols;
  final mask = scaled.toMask();

  const solver = Solver();
  final rng = Random(42);

  // 1. Generate full dense board with 28 arrows using reverse placement
  final free = <GridCell>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (mask[r * cols + c]) free.add(GridCell(r, c));
    }
  }
  final occupied = <GridCell, String>{};
  final arrows = <Arrow>[];

  while (arrows.length < maxArrows && free.isNotEmpty) {
    final starts = free.toList()..shuffle(rng);
    Arrow? best;
    for (final head in starts) {
      if (best != null) break;
      final dirs = [...DirectionX.orthogonal]..shuffle(rng);
      for (final dir in dirs) {
        var cell = head.shift(dir);
        var clear = true;
        while (cell.inside(rows, cols)) {
          if (occupied.containsKey(cell)) {
            clear = false;
            break;
          }
          cell = cell.shift(dir);
        }
        if (!clear) continue;
        final path = walkBackwards(head, dir, 3 + rng.nextInt(3), free, rows, cols, mask, rng);
        if (path.length >= 3) {
          best = Arrow(id: 'a${arrows.length}', path: path, dir: dir);
          break;
        }
      }
    }
    if (best == null) break;
    arrows.add(best);
    for (final c in best.path) {
      free.remove(c);
      occupied[c] = best.id;
    }
  }

  // Extend leftovers
  extendTails(arrows, free, occupied, rows, cols);

  final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
  print('Generated board: ${arrows.length} arrows, solvable=${solver.solvableByGreedy(board)}');

  // Let's analyze the dependency graph
  final graph = solver.dependencyGraph(board);

  // In the greedy solve:
  // Can we modify individual arrows by:
  // 1. Changing an arrow's arrowhead direction (dir) to face an arrow that is removed AFTER it!
  // If an arrow's dir changes from pointing off-screen to pointing into another arrow,
  // it now DEPENDS on that arrow!
  // Does it still solve?
  // If arrow A was free, but we make A point at arrow B (where B does NOT depend on A),
  // then A depends on B!
  // A is no longer free! A will become free ONLY AFTER B is removed!
  // Let's test this!
  var modCount = 0;
  for (var i = 0; i < arrows.length; i++) {
    final a = arrows[i];
    // Check if a currently has ray clear to edge
    final ray = board.exitRay(a);
    final blockers = ray.where((c) => occupied.containsKey(c)).toList();
    if (blockers.isEmpty) {
      // 'a' is free!
      // Can 'a' point in another direction from its head, or from its tail?
      // Let's check other directions from a.head:
      for (final newDir in DirectionX.orthogonal) {
        if (newDir == a.dir) continue;
        // If head shifts newDir, does it hit an arrow?
        var c = a.head.shift(newDir);
        var hitArrowId = '';
        while (c.inside(rows, cols)) {
          final occ = board.occupancy[c];
          if (occ != null && occ.id != a.id) {
            hitArrowId = occ.id;
            break;
          }
          c = c.shift(newDir);
        }
        if (hitArrowId.isNotEmpty) {
          // Check if changing a.dir to newDir keeps board solvable
          final testArrow = Arrow(id: a.id, path: a.path, dir: newDir);
          final testArrows = List<Arrow>.from(arrows);
          testArrows[i] = testArrow;
          final testBoard = Board(rows: rows, cols: cols, mask: mask, arrows: testArrows);
          if (solver.solvableByGreedy(testBoard)) {
            arrows[i] = testArrow;
            modCount++;
            print('Re-aimed ${a.id} towards $hitArrowId (newDir $newDir)');
            break;
          }
        }
      }
    }
  }

  final finalBoard = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
  final m = DifficultyConfig.evaluate(finalBoard);
  print('After re-aiming: modCount=$modCount, maxWave=${m.maxFreeWave}, free0=${m.free0}, avgFree=${m.avgFree}');
}

void extendTails(List<Arrow> arrows, Set<GridCell> free, Map<GridCell, String> occupied, int rows, int cols) {
  var changed = true;
  while (changed && free.isNotEmpty) {
    changed = false;
    for (final cell in free.toList()) {
      for (var i = 0; i < arrows.length; i++) {
        final arrow = arrows[i];
        final tail = arrow.tail;
        if ((tail.row - cell.row).abs() + (tail.col - cell.col).abs() == 1) {
          arrows[i] = Arrow(id: arrow.id, path: [cell, ...arrow.path], dir: arrow.dir);
          occupied[cell] = arrow.id;
          free.remove(cell);
          changed = true;
          break;
        }
      }
      if (changed) break;
    }
  }
}

List<GridCell> walkBackwards(GridCell head, Direction forwardDir, int targetLen, Set<GridCell> free, int rows, int cols, List<bool> mask, Random rng) {
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
      if (step.inside(rows, cols) && mask[step.row * cols + step.col] && free.contains(step) && !claimed.contains(step)) {
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

