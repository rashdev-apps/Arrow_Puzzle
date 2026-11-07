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

  final free = <GridCell>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (mask[r * cols + c]) free.add(GridCell(r, c));
    }
  }
  final occupied = <GridCell, String>{};
  final arrows = <Arrow>[];

  // In reverse placement:
  // arrows[0] will be removed LAST (Rn).
  // arrows[1] will be removed (Rn-1).
  // ...
  // arrows.last will be removed FIRST (R1).
  //
  // When placing arrows[k]:
  // To keep max_free = 1 (or 2):
  // At the start of the game, only arrows.last (R1) should have its exit ray completely clear!
  // All other arrows (arrows[0..N-2]) MUST have their exit ray blocked by some arrow placed AFTER them!
  //
  // Specifically:
  // If every arrow arrows[i] (for i < N-1) has its exit ray blocked by arrows[i+1],
  // then when R1 is removed, ONLY R2 is unlocked!
  // When R2 is removed, ONLY R3 is unlocked!

  // Let's test placing each new arrow X such that X blocks the exit ray of the PREVIOUS arrow in reverse order:
  // BUT the previous arrow in reverse order is arrows.last!
  // That means arrows.last's exit ray must pass through X!
  // Does arrows.last's exit ray have free cells?
  // YES! Because arrows.last was just placed, and its exit ray was clear of arrows[0..last-1]!
  // So its exit ray currently consists of FREE CELLS (and board edge)!
  // Therefore, X CAN be placed on the exit ray of arrows.last!
}

