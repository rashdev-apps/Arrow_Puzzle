import '../domain/arrow.dart';
import '../domain/board.dart';
import '../domain/grid_cell.dart';

/// Outcome of evaluating a tap on an arrow.
class MoveResult {
  /// True when the exit ray is clear and the arrow may slide out.
  final bool valid;

  /// Arrows (other than the tapped one) sitting on the exit ray.
  final List<Arrow> blockers;

  /// Ray cells from the head up to and including the first blocking cell.
  /// Empty when [valid]. Used to highlight the blocked path in red.
  final List<GridCell> blockedRay;

  const MoveResult.valid()
      : valid = true,
        blockers = const [],
        blockedRay = const [];

  const MoveResult.blocked(this.blockers, this.blockedRay) : valid = false;
}

/// Pure move validation, UI-independent.
class MoveValidator {
  const MoveValidator();

  MoveResult evaluate(
    Board board,
    Arrow arrow,
    Set<String> remainingIds,
  ) {
    final occ = board.occupancy;
    final blockers = <Arrow>[];
    final ray = <GridCell>[];
    for (final cell in board.exitRay(arrow)) {
      ray.add(cell);
      final other = occ[cell];
      if (other != null && other.id != arrow.id) {
        if (remainingIds.contains(other.id) && !blockers.contains(other)) {
          blockers.add(other);
        }
        // Keep scanning so the full blocked path is highlighted even past
        // the first blocker; only remaining arrows block the move.
      }
    }
    final activeBlockers = blockers.where((b) => remainingIds.contains(b.id));
    if (activeBlockers.isEmpty) return const MoveResult.valid();
    return MoveResult.blocked(
      activeBlockers.toList(growable: false),
      ray,
    );
  }
}
