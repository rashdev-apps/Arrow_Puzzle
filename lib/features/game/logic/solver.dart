import '../domain/arrow.dart';
import '../domain/board.dart';

/// Result of analysing a board's dependency structure.
class BoardAnalysis {
  /// One valid full removal order (length = arrow count) when solvable.
  final List<String>? solutionOrder;

  /// Longest dependency chain depth (1 = every arrow free at start).
  final int longestChain;

  /// Number of arrows free on the initial board.
  final int freeAtStart;

  /// Average arrow path length in cells.
  final double averagePathLength;

  bool get isSolvable => solutionOrder != null;

  int get arrowCount => dependencyGraph.length;

  /// arrowId -> ids of arrows currently blocking its exit ray.
  final Map<String, Set<String>> dependencyGraph;

  const BoardAnalysis({
    required this.solutionOrder,
    required this.dependencyGraph,
    required this.longestChain,
    required this.freeAtStart,
    required this.averagePathLength,
  });
}

/// Pure solving / analysis utilities for arrow boards.
class Solver {
  const Solver();

  /// Build the dependency graph: arrow -> set of arrows blocking its exit ray.
  Map<String, Set<String>> dependencyGraph(Board board) {
    final occ = board.occupancy;
    final graph = <String, Set<String>>{};
    for (final arrow in board.arrows) {
      final blockers = <String>{};
      for (final cell in board.exitRay(arrow)) {
        final other = occ[cell];
        if (other != null && other.id != arrow.id) {
          blockers.add(other.id);
        }
      }
      graph[arrow.id] = blockers;
    }
    return graph;
  }

  /// Kahn topological sort on the live dependency graph. Returns a valid
  /// removal order, or `null` when the graph has a cycle (unsolvable).
  List<String>? solutionOrder(Board board) => analyze(board).solutionOrder;

  BoardAnalysis analyze(Board board) {
    final graph = dependencyGraph(board);
    final remaining = graph.keys.toSet();
    final order = <String>[];

    // Kahn's algorithm: repeatedly remove arrows with no live blockers.
    while (remaining.isNotEmpty) {
      final free = remaining
          .where((id) => graph[id]!.every((b) => !remaining.contains(b)))
          .toList()
        ..sort();
      if (free.isEmpty) {
        return BoardAnalysis(
          solutionOrder: null,
          dependencyGraph: graph,
          longestChain: 0,
          freeAtStart: graph.keys
              .where((id) => graph[id]!.isEmpty)
              .length,
          averagePathLength: _avgPathLength(board),
        );
      }
      order.addAll(free);
      remaining.removeAll(free);
    }

    return BoardAnalysis(
      solutionOrder: order,
      dependencyGraph: graph,
      longestChain: _longestChain(graph),
      freeAtStart: graph.keys.where((id) => graph[id]!.isEmpty).length,
      averagePathLength: _avgPathLength(board),
    );
  }

  /// Greedy solver simulating actual play: always remove *some* currently
  /// free arrow. Succeeds iff the board is solvable.
  bool solvableByGreedy(Board board) {
    final remaining = board.arrows.map((a) => a.id).toSet();
    final validatorOcc = board.occupancy;
    while (remaining.isNotEmpty) {
      Arrow? pick;
      for (final arrow in board.arrows) {
        if (!remaining.contains(arrow.id)) continue;
        var free = true;
        for (final cell in board.exitRay(arrow)) {
          final other = validatorOcc[cell];
          if (other != null &&
              other.id != arrow.id &&
              remaining.contains(other.id)) {
            free = false;
            break;
          }
        }
        if (free) {
          pick = arrow;
          break;
        }
      }
      if (pick == null) return false;
      remaining.remove(pick.id);
    }
    return true;
  }

  int _longestChain(Map<String, Set<String>> graph) {
    final memo = <String, int>{};
    int depth(String id, Set<String> stack) {
      final cached = memo[id];
      if (cached != null) return cached;
      if (stack.contains(id)) return 0; // cycle guard; boards are DAGs
      stack.add(id);
      var best = 1;
      for (final blocker in graph[id]!) {
        best = best > depth(blocker, stack) + 1 ? best : depth(blocker, stack) + 1;
      }
      stack.remove(id);
      return memo[id] = best;
    }

    var max = 1;
    for (final id in graph.keys) {
      final d = depth(id, <String>{});
      if (d > max) max = d;
    }
    return max;
  }

  double _avgPathLength(Board board) {
    if (board.arrows.isEmpty) return 0;
    var sum = 0;
    for (final a in board.arrows) {
      sum += a.length;
    }
    return sum / board.arrows.length;
  }
}
