import 'package:equatable/equatable.dart';

import '../models/board.dart';
import '../models/direction.dart';
import '../models/grid_cell.dart';

sealed class MoveOutcome extends Equatable {
  const MoveOutcome();
}

class ValidMove extends MoveOutcome {
  final String arrowId;
  final Direction dir;
  const ValidMove(this.arrowId, this.dir);

  @override
  List<Object?> get props => [arrowId, dir];
}

class BlockedMove extends MoveOutcome {
  final String arrowId;
  final List<String> blockerIds;
  final List<GridCell> blockedRay;
  const BlockedMove({
    required this.arrowId,
    required this.blockerIds,
    required this.blockedRay,
  });

  @override
  List<Object?> get props => [arrowId, blockerIds, blockedRay];
}

class IgnoredMove extends MoveOutcome {
  const IgnoredMove();

  @override
  List<Object?> get props => [];
}

class MoveRules {
  const MoveRules();

  MoveOutcome testMove(Board board, Set<String> remaining, String arrowId) {
    if (!remaining.contains(arrowId)) return const IgnoredMove();
    final arrow = board.arrowById(arrowId);
    if (arrow == null) return const IgnoredMove();

    final occ = board.occupancy;
    final ray = board.exitRay(arrow);
    final blockers = <String>[];
    final activeBlockedRay = <GridCell>[];

    for (final cell in ray) {
      activeBlockedRay.add(cell);
      final occupant = occ[cell];
      if (occupant != null &&
          occupant.id != arrowId &&
          remaining.contains(occupant.id)) {
        blockers.add(occupant.id);
      }
    }

    if (blockers.isEmpty) {
      return ValidMove(arrowId, arrow.dir);
    } else {
      return BlockedMove(
        arrowId: arrowId,
        blockerIds: blockers,
        blockedRay: activeBlockedRay,
      );
    }
  }

  bool canEscape(Board board, Set<String> remaining, String arrowId) {
    return testMove(board, remaining, arrowId) is ValidMove;
  }
}

