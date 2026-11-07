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

  // Strategy:
  // Step 1: Pack the board with high density (25-35 winding arrows) using reverse placement.
  // This guarantees 100% solvability and >= 90% coverage!
  //
  // Step 2: Now, analyze the board's solve order and dependency graph.
  // If at any step, free count > allowedMaxFree (e.g. > 1 or 2):
  // Why is free count > 1?
  // Because two arrows A and B both have clear exit rays at that moment!
  // Can we make A block B, or adjust arrow paths/orientations, or can we prune/re-orient?
  //
  // Wait! What if we generate arrows in FORWARD order (R1 -> R2 -> ... -> Rn)?
  // Let's trace forward order:
  // R1 is placed: its exit ray to board edge MUST be completely CLEAR.
  // Now place R2:
  // At the start of the game, R2 MUST BE BLOCKED!
  // By whom? By R1!
  // So R2's exit ray MUST cross R1!
  // And R2's exit ray MUST NOT cross any cell outside R1 that will be occupied later,
  // OR when R1 leaves, R2 becomes clear!
}

