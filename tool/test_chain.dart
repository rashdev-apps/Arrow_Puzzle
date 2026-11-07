it // Testing adding in-chain filler arrows and branching arrows
import 'dart:math';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/logic/generator/shapes.dart';

Direction _turnLeft(Direction d) => switch (d) {
      Direction.up => Direction.left,
      Direction.left => Direction.down,
      Direction.down => Direction.right,
      Direction.right => Direction.up,
    };

Direction _turnRight(Direction d) => switch (d) {
      Direction.up => Direction.right,
      Direction.right => Direction.down,
      Direction.down => Direction.left,
      Direction.left => Direction.up,
    };

Direction? lastStepDir(List<GridCell> path) {
  if (path.length < 2) return null;
  final a = path[path.length - 2];
  final b = path.last;
  final dr = b.row - a.row;
  final dc = b.col - a.col;
  if (dr == -1) return Direction.up;
  if (dr == 1) return Direction.down;
  if (dc == -1) return Direction.left;
  if (dc == 1) return Direction.right;
  return null;
}

List<GridCell> snakeFromAnchor(
  Random rng,
  GridCell anchor,
  int targetLen,
  Set<GridCell> free,
  int rows,
  int cols,
  List<bool> mask,
) {
  final path = <GridCell>[anchor];
  final visited = <GridCell>{anchor};

  // Grow forward
  var curr = anchor;
  var currentDir = Direction.values[rng.nextInt(Direction.values.length)];
  final forwardSteps = rng.nextInt(targetLen);

  for (var i = 0; i < forwardSteps; i++) {
    final dirs = [
      currentDir,
      _turnLeft(currentDir),
      _turnRight(currentDir),
    ]..shuffle(rng);

    GridCell? next;
    for (final d in dirs) {
      final cand = curr.shift(d);
      if (cand.inside(rows, cols) &&
          mask[cand.row * cols + cand.col] &&
          free.contains(cand) &&
          !visited.contains(cand)) {
        next = cand;
        currentDir = d;
        break;
      }
    }
    if (next == null) break;
    path.add(next);
    visited.add(next);
    curr = next;
  }

  // Grow backward from start
  var tail = path.first;
  var tailDir = currentDir.opposite;
  while (path.length < targetLen) {
    final dirs = [
      tailDir,
      _turnLeft(tailDir),
      _turnRight(tailDir),
    ]..shuffle(rng);

    GridCell? prev;
    for (final d in dirs) {
      final cand = tail.shift(d);
      if (cand.inside(rows, cols) &&
          mask[cand.row * cols + cand.col] &&
          free.contains(cand) &&
          !visited.contains(cand)) {
        prev = cand;
        tailDir = d;
        break;
      }
    }
    if (prev == null) break;
    path.insert(0, prev);
    visited.add(prev);
    tail = prev;
  }

  return path;
}

/// Extends existing arrows' tails into adjacent free cells without touching their heads or directions
void extendTailsSafely(Set<GridCell> free, Map<GridCell, String> occupied, List<Arrow> chain, int rows, int cols, List<bool> mask, int allowedMaxFree) {
  var changed = true;
  var passes = 0;
  while (changed && passes < 10) {
    changed = false;
    passes++;
    final candidateCells = free.toList()..shuffle();
    for (final cell in candidateCells) {
      if (!free.contains(cell)) continue;
      // Find adjacent tails
      for (var i = 0; i < chain.length; i++) {
        final arrow = chain[i];
        final tail = arrow.tail;
        final dist = (tail.row - cell.row).abs() + (tail.col - cell.col).abs();
        if (dist == 1) {
          final oldArrow = arrow;
          final newPath = [cell, ...arrow.path];
          final newArrow = Arrow(id: arrow.id, path: newPath, dir: arrow.dir);
          chain[i] = newArrow;

          final testBoard = Board(rows: rows, cols: cols, mask: mask, arrows: chain.reversed.toList());
          final remaining = testBoard.arrows.map((a) => a.id).toSet();
          var solvable = true;
          var maxF = 0;
          while (remaining.isNotEmpty) {
            final fl = testBoard.freeArrows(remaining);
            if (fl.isEmpty) {
              solvable = false;
              break;
            }
            if (fl.length > maxF) maxF = fl.length;
            if (maxF > allowedMaxFree) {
              solvable = false;
              break;
            }
            remaining.remove(fl.first.id);
          }

          if (solvable && maxF <= allowedMaxFree) {
            free.remove(cell);
            occupied[cell] = arrow.id;
            changed = true;
            break;
          } else {
            chain[i] = oldArrow;
          }
        }
      }
    }
  }
}

/// Try to insert decoy/extra arrows into the chain
void insertDecoyArrows(
  Set<GridCell> free,
  Map<GridCell, String> occupied,
  List<Arrow> chain,
  int rows,
  int cols,
  List<bool> mask,
  int allowedMaxFree,
  Random rng,
) {
  // A decoy arrow X can be inserted between chain[k] and chain[k+1] or anywhere in placement order
  // if when tested with evaluateChain, the puzzle remains 100% solvable and max_free <= allowedMaxFree!
  final starts = free.toList()..shuffle(rng);
  for (final start in starts) {
    if (free.length < 5) break;
    for (var len = 3; len <= 5; len++) {
      final p = snakeFromAnchor(rng, start, len, free, rows, cols, mask);
      if (p.length < 3) continue;
      final d = lastStepDir(p);
      if (d == null) continue;

      final cand = Arrow(id: 'decoy_${chain.length}', path: p, dir: d);

      // Try inserting cand at various positions in placement chain
      var inserted = false;
      for (var pos = 0; pos <= chain.length; pos += 2) {
        final testChain = List<Arrow>.from(chain)..insert(pos, cand);
        final testBoard = Board(rows: rows, cols: cols, mask: mask, arrows: testChain.reversed.toList());
        final remaining = testBoard.arrows.map((a) => a.id).toSet();
        var solvable = true;
        var maxF = 0;
        while (remaining.isNotEmpty) {
          final fl = testBoard.freeArrows(remaining);
          if (fl.isEmpty) {
            solvable = false;
            break;
          }
          if (fl.length > maxF) maxF = fl.length;
          if (maxF > allowedMaxFree) {
            solvable = false;
            break;
          }
          remaining.remove(fl.first.id);
        }

        if (solvable && maxF <= allowedMaxFree) {
          chain.insert(pos, cand);
          for (final c in p) {
            free.remove(c);
            occupied[c] = cand.id;
          }
          inserted = true;
          break;
        }
      }
      if (inserted) break;
    }
  }
}

void main() {
  final shape = kBuiltinShapes.first; // square
  final rows = 14;
  final cols = 14;
  final mask = shape.resized(rows, cols).toMask();
  final rng = Random(42);

  final totalMasked = mask.where((m) => m).length;
  final free = <GridCell>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (mask[r * cols + c]) free.add(GridCell(r, c));
    }
  }

  final occupied = <GridCell, String>{};
  final chain = <Arrow>[];

  // 1. Build spine chain
  final st = free.first;
  final p0 = snakeFromAnchor(rng, st, 4, free, rows, cols, mask);
  final d0 = lastStepDir(p0)!;
  final a0 = Arrow(id: 'a0', path: p0, dir: d0);
  chain.add(a0);
  for (final c in p0) {
    free.remove(c);
    occupied[c] = a0.id;
  }

  bool dfs(int depth, int targetLen) {
    if (chain.length >= targetLen) return true;
    if (depth > targetLen * 3) return false;

    final prev = chain.last;
    final rayCells = <GridCell>[];
    var ray = prev.head.shift(prev.dir);
    while (ray.inside(rows, cols)) {
      if (free.contains(ray)) rayCells.add(ray);
      ray = ray.shift(prev.dir);
    }
    if (rayCells.isEmpty) return false;
    rayCells.shuffle(rng);

    for (final anchor in rayCells.take(8)) {
      for (var t = 0; t < 6; t++) {
        final len = 3 + rng.nextInt(4);
        final p = snakeFromAnchor(rng, anchor, len, free, rows, cols, mask);
        if (p.length < 3) continue;
        final d = lastStepDir(p);
        if (d == null) continue;

        var exit = p.last.shift(d);
        var clear = true;
        while (exit.inside(rows, cols)) {
          if (occupied.containsKey(exit) || p.contains(exit)) {
            clear = false;
            break;
          }
          exit = exit.shift(d);
        }
        if (!clear) continue;

        final cand = Arrow(id: 'a${chain.length}', path: p, dir: d);
        chain.add(cand);
        for (final c in p) {
          free.remove(c);
          occupied[c] = cand.id;
        }

        if (dfs(depth + 1, targetLen)) return true;

        chain.removeLast();
        for (final c in p) {
          free.add(c);
          occupied.remove(c);
        }
      }
    }
    return false;
  }

  dfs(0, 25);
  print('Spine chain length: ${chain.length}, free cells left: ${free.length}');

  // 2. Insert decoy/branch arrows
  insertDecoyArrows(free, occupied, chain, rows, cols, mask, 1, rng);
  print('After decoy insertion: arrows=${chain.length}, free cells left: ${free.length}');

  // 3. Extend tails safely
  extendTailsSafely(free, occupied, chain, rows, cols, mask, 1);
  final coverage = occupied.length / totalMasked;
  print('After safe tail extension: occupied=${occupied.length}/$totalMasked (${(coverage * 100).toStringAsFixed(1)}%)');

  // Verify greedy solve
  final board = Board(rows: rows, cols: cols, mask: mask, arrows: chain.reversed.toList());
  final remaining = board.arrows.map((a) => a.id).toSet();
  var maxF = 0;
  var totalF = 0;
  var steps = 0;
  while (remaining.isNotEmpty) {
    final fl = board.freeArrows(remaining);
    if (fl.isEmpty) {
      print('Stuck at step $steps!');
      break;
    }
    if (fl.length > maxF) maxF = fl.length;
    totalF += fl.length;
    remaining.remove(fl.first.id);
    steps++;
  }
  print('Verified: steps=$steps, maxFree=$maxF, avgFree=${(totalF / steps).toStringAsFixed(2)}');
}
