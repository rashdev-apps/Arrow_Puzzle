import '../models/arrow.dart';
import '../models/board.dart';
import '../rules/move_rules.dart';

class SolverAnalysis {
  final List<String>? solutionOrder;
  final Map<String, Set<String>> dependencyGraph;
  final int longestChain;
  final int freeAtStart;
  final int maxFreeWave;
  final double avgFree;

  bool get isSolvable => solutionOrder != null;

  const SolverAnalysis({
    required this.solutionOrder,
    required this.dependencyGraph,
    required this.longestChain,
    required this.freeAtStart,
    required this.maxFreeWave,
    required this.avgFree,
  });
}

class Solver {
  final MoveRules rules;
  const Solver({this.rules = const MoveRules()});

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

  SolverAnalysis analyze(Board board) {
    final graph = dependencyGraph(board);
    final remaining = graph.keys.toSet();
    final order = <String>[];
    var maxWave = 0;
    var totalWave = 0;
    var steps = 0;

    final initialFree = graph.keys.where((id) => graph[id]!.isEmpty).length;

    while (remaining.isNotEmpty) {
      final free = remaining
          .where((id) => graph[id]!.every((b) => !remaining.contains(b)))
          .toList()
        ..sort();

      if (free.isEmpty) {
        return SolverAnalysis(
          solutionOrder: null,
          dependencyGraph: graph,
          longestChain: 0,
          freeAtStart: initialFree,
          maxFreeWave: maxWave,
          avgFree: steps == 0 ? 0.0 : totalWave / steps,
        );
      }

      if (free.length > maxWave) maxWave = free.length;
      totalWave += free.length;
      steps++;

      // Greedy deterministic step: take the first free arrow
      final pick = free.first;
      order.add(pick);
      remaining.remove(pick);
    }

    return SolverAnalysis(
      solutionOrder: order,
      dependencyGraph: graph,
      longestChain: _computeLongestChain(graph),
      freeAtStart: initialFree,
      maxFreeWave: maxWave,
      avgFree: steps == 0 ? 0.0 : totalWave / steps,
    );
  }

  bool isSolvable(Board board) => analyze(board).isSolvable;

  int _computeLongestChain(Map<String, Set<String>> graph) {
    final memo = <String, int>{};
    int depth(String id, Set<String> visited) {
      final cached = memo[id];
      if (cached != null) return cached;
      if (visited.contains(id)) return 0; // cycle guard
      visited.add(id);
      var maxD = 1;
      for (final blocker in graph[id]!) {
        final d = depth(blocker, visited) + 1;
        if (d > maxD) maxD = d;
      }
      visited.remove(id);
      return memo[id] = maxD;
    }

    var best = 1;
    for (final id in graph.keys) {
      final d = depth(id, <String>{});
      if (d > best) best = d;
    }
    return best;
  }
}
