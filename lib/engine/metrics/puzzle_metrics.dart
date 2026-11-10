import '../models/board.dart';
import '../models/arrow.dart';
import '../solver.dart';

class PuzzleQualityMetrics {
  final int arrowCount;
  final int freeAtStart;
  final int longestChain;
  final int maxFreeWave;
  final double avgFree;
  final double coverage;
  final double avgBlockersPerArrow;
  final int decoyCount;
  final double difficultyScore;
  final bool isSolvable;

  const PuzzleQualityMetrics({
    required this.arrowCount,
    required this.freeAtStart,
    required this.longestChain,
    required this.maxFreeWave,
    required this.avgFree,
    required this.coverage,
    required this.avgBlockersPerArrow,
    required this.decoyCount,
    required this.difficultyScore,
    required this.isSolvable,
  });

  static PuzzleQualityMetrics evaluate(Board board, {Solver solver = const Solver()}) {
    final N = board.arrows.length;
    if (N == 0) {
      return const PuzzleQualityMetrics(
        arrowCount: 0,
        freeAtStart: 0,
        longestChain: 0,
        maxFreeWave: 0,
        avgFree: 0,
        coverage: 0,
        avgBlockersPerArrow: 0,
        decoyCount: 0,
        difficultyScore: 0,
        isSolvable: false,
      );
    }

    final analysis = solver.analyze(board);
    final isSolvable = analysis.isSolvable;
    final graph = analysis.dependencyGraph;

    var totalBlockers = 0;
    var decoys = 0;

    for (final blockers in graph.values) {
      totalBlockers += blockers.length;
      if (blockers.length == 1) decoys++;
    }

    final avgBlockers = totalBlockers / N;
    final depthRatio = analysis.longestChain / N;
    final maxFreeRatio = analysis.maxFreeWave / N;

    final score = (depthRatio * 40.0) +
        ((1.0 - maxFreeRatio.clamp(0.0, 1.0)) * 25.0) +
        (avgBlockers * 15.0) +
        (board.coverage * 20.0);

    return PuzzleQualityMetrics(
      arrowCount: N,
      freeAtStart: analysis.freeAtStart,
      longestChain: analysis.longestChain,
      maxFreeWave: analysis.maxFreeWave,
      avgFree: analysis.avgFree,
      coverage: board.coverage,
      avgBlockersPerArrow: avgBlockers,
      decoyCount: decoys,
      difficultyScore: score,
      isSolvable: isSolvable,
    );
  }
}

