import 'dart:math';

import '../domain/arrow.dart';
import '../domain/board.dart';
import 'solver.dart';

/// Target metrics for a specific level.
class LevelDifficultyTarget {
  final int levelId;
  final int minArrows;
  final int maxArrows;
  final int minChain;
  final double maxFreeRatio;
  final double minRayBlockers;
  final double minScore;

  const LevelDifficultyTarget({
    required this.levelId,
    required this.minArrows,
    required this.maxArrows,
    required this.minChain,
    required this.maxFreeRatio,
    required this.minRayBlockers,
    required this.minScore,
  });
}

/// Comprehensive quality and difficulty metrics computed for any board.
class BoardQualityMetrics {
  final int arrowCount;
  final int free0;
  final double free0Ratio;
  final int longestChain;
  final double depthRatio;
  final double avgRayBlockers;
  final double multiBlockerRatio;
  final int maxFreeWave;
  final double maxFreeWaveRatio;
  final double avgFree;
  final int decoyCount;
  final double coverage;
  final double windingRatio;
  final double difficultyScore;
  final bool isSolvable;
  final bool isForcedOrder;

  const BoardQualityMetrics({
    required this.arrowCount,
    required this.free0,
    required this.free0Ratio,
    required this.longestChain,
    required this.depthRatio,
    required this.avgRayBlockers,
    required this.multiBlockerRatio,
    required this.maxFreeWave,
    required this.maxFreeWaveRatio,
    required this.avgFree,
    required this.decoyCount,
    required this.coverage,
    required this.windingRatio,
    required this.difficultyScore,
    required this.isSolvable,
    required this.isForcedOrder,
  });

  /// Evaluates whether this board meets all mandatory quality thresholds.
  bool isValidFor(int levelId) {
    final N = arrowCount;
    if (N < 15) return false;
    if (!isSolvable) return false;
    if (coverage < 0.85) return false;

    // Chain puzzle constraints:
    if (levelId <= 15) {
      // Early levels: teach mechanic, up to 2 free arrows allowed
      if (maxFreeWave > 2) return false;
      if (free0 > 2) return false;
    } else {
      // Mid & Late levels: high dependency, low concurrency
      // maxFreeWave <= 2 allowed, with avgFree <= 1.25 and free0 <= 2
      if (maxFreeWave > 2) return false;
      if (free0 > 2) return false;
      if (avgFree > 1.25) return false;
    }

    return true;
  }
}

/// Central difficulty configuration and quality calculator.
abstract final class DifficultyConfig {
  static const int chapterSize = 20;
  static const int totalLevels = 200;

  /// Target arrow count range for a given level id.
  /// L1-L4: 40-50
  /// L5-L8: 50-60
  /// L9-L12: 60-70
  /// L13-L16: 70-80
  /// L17-L19: 80-90
  /// L20 (boss): 90-110
  /// Later shapes get +3 per chapter, capped at 120.
  static (int min, int max) targetArrowCount(int levelId) {
    final chapter = (levelId - 1) ~/ chapterSize;
    final indexInChapter = (levelId - 1) % chapterSize + 1;
    final chapterBonus = min(8, chapter);

    int baseMin;
    int baseMax;
    if (indexInChapter <= 4) {
      baseMin = 20;
      baseMax = 42;
    } else if (indexInChapter <= 8) {
      baseMin = 22;
      baseMax = 50;
    } else if (indexInChapter <= 12) {
      baseMin = 24;
      baseMax = 58;
    } else if (indexInChapter <= 16) {
      baseMin = 26;
      baseMax = 65;
    } else if (indexInChapter <= 19) {
      baseMin = 28;
      baseMax = 72;
    } else {
      baseMin = 30;
      baseMax = 82;
    }

    final minArrows = min(40, baseMin + chapterBonus);
    final maxArrows = min(85, baseMax + chapterBonus);
    return (minArrows, maxArrows);
  }

  /// Grid size scaled up so that coverage stays >= 92% with large arrow counts.
  static int targetGridSize(int levelId) {
    final (minArrows, maxArrows) = targetArrowCount(levelId);
    final targetN = (minArrows + maxArrows) ~/ 2;
    final cellsNeeded = targetN * 4.3;
    final side = sqrt(cellsNeeded).round();
    return side.clamp(14, 25);
  }

  /// Calculates all quality metrics for a board.
  static BoardQualityMetrics evaluate(Board board) {
    const solver = Solver();
    final graph = solver.dependencyGraph(board);
    final analysis = solver.analyze(board);

    final N = board.arrows.length;
    if (N == 0 || !analysis.isSolvable) {
      return BoardQualityMetrics(
        arrowCount: N,
        free0: 0,
        free0Ratio: 0,
        longestChain: 0,
        depthRatio: 0,
        avgRayBlockers: 0,
        multiBlockerRatio: 0,
        maxFreeWave: 0,
        maxFreeWaveRatio: 0,
        avgFree: 0,
        decoyCount: 0,
        coverage: 0,
        windingRatio: 0,
        difficultyScore: 0,
        isSolvable: false,
        isForcedOrder: false,
      );
    }

    final free0 = analysis.freeAtStart;
    final free0Ratio = free0 / N;
    final longestChain = analysis.longestChain;
    final depthRatio = longestChain / N;

    // Ray blockers count
    var totalBlockers = 0;
    var multiBlockersCount = 0;
    for (final blockers in graph.values) {
      totalBlockers += blockers.length;
      if (blockers.length >= 2) multiBlockersCount++;
    }
    final avgRayBlockers = totalBlockers / N;
    final multiBlockerRatio = multiBlockersCount / N;

    // Simulate step-by-step solve to measure maxFree, avgFree, decoys, and forced order
    var maxWave = free0;
    var totalFreeAcrossSteps = 0;
    var steps = 0;
    var decoyCount = 0;
    final remaining = graph.keys.toSet();
    while (remaining.isNotEmpty) {
      final freeNow = remaining
          .where((id) => graph[id]!.every((b) => !remaining.contains(b)))
          .toList();
      if (freeNow.isEmpty) break;
      if (freeNow.length > maxWave) maxWave = freeNow.length;
      totalFreeAcrossSteps += freeNow.length;
      steps++;

      // Decoys: arrows blocked by only 1 arrow that is not yet removable
      final almostFree = remaining.where((id) {
        if (freeNow.contains(id)) return false;
        final unremovedBlockers = graph[id]!.where((b) => remaining.contains(b)).length;
        return unremovedBlockers == 1;
      }).length;
      decoyCount += almostFree;

      // In a real player solve, remove one free arrow
      remaining.remove(freeNow.first);
    }
    final avgFree = steps > 0 ? totalFreeAcrossSteps / steps : 0.0;
    final isForcedOrder = maxWave <= 1;
    final maxFreeWaveRatio = maxWave / N;

    // Winding ratio: arrows with >= 3 turns
    var windingCount = 0;
    for (final arrow in board.arrows) {
      if (_countTurns(arrow) >= 3) windingCount++;
    }
    final windingRatio = windingCount / N;

    // Coverage
    final totalMasked = board.maskedCellCount;
    final occupied = board.occupancy.length;
    final coverage = totalMasked > 0 ? occupied / totalMasked : 0.0;

    // difficulty_score = 0.35*depth_ratio + 0.25*avg_ray_blockers_norm + 0.2*(1 - free0_ratio) + 0.2*winding_ratio
    final avgBlockersNorm = (avgRayBlockers / 4.0).clamp(0.0, 1.0);
    final score = 0.35 * depthRatio +
        0.25 * avgBlockersNorm +
        0.20 * (1.0 - free0Ratio) +
        0.20 * windingRatio;

    return BoardQualityMetrics(
      arrowCount: N,
      free0: free0,
      free0Ratio: free0Ratio,
      longestChain: longestChain,
      depthRatio: depthRatio,
      avgRayBlockers: avgRayBlockers,
      multiBlockerRatio: multiBlockerRatio,
      maxFreeWave: maxWave,
      maxFreeWaveRatio: maxFreeWaveRatio,
      avgFree: double.parse(avgFree.toStringAsFixed(2)),
      decoyCount: decoyCount,
      coverage: coverage,
      windingRatio: windingRatio,
      difficultyScore: double.parse(score.toStringAsFixed(4)),
      isSolvable: true,
      isForcedOrder: isForcedOrder,
    );
  }

  static int _countTurns(Arrow arrow) {
    final path = arrow.path;
    if (path.length < 3) return 0;
    var turns = 0;
    for (var i = 1; i < path.length - 1; i++) {
      final prev = path[i - 1];
      final curr = path[i];
      final next = path[i + 1];
      final d1r = curr.row - prev.row;
      final d1c = curr.col - prev.col;
      final d2r = next.row - curr.row;
      final d2c = next.col - curr.col;
      if (d1r != d2r || d1c != d2c) turns++;
    }
    return turns;
  }

  // ---- Countdown Timer Configuration -----------------------------------------
  static const double secPerArrowEasy = 6.0;   // Levels 1-5 (after intro) / easy tier
  static const double secPerArrowMedium = 5.0; // Levels 6-12
  static const double secPerArrowHard = 4.0;   // Levels 13-19
  static const double secPerArrowBoss = 3.5;   // Level 20 (boss level)

  static const int minTimeLimitSeconds = 45;
  static const int maxTimeLimitSeconds = 600;

  static const int mistakePenaltySeconds = 3;
  static const int reviveSecondsBonus = 30;
  static const int freezePowerupSeconds = 10;
  static const int freezePowerupCost = 15;

  /// Returns seconds per arrow based on relative position within a chapter.
  /// indexInChapter: 1..20
  static double secPerArrowForLevel(int levelId) {
    final indexInChapter = ((levelId - 1) % 20) + 1;
    if (indexInChapter == 20) return secPerArrowBoss;
    if (indexInChapter >= 13) return secPerArrowHard;
    if (indexInChapter >= 6) return secPerArrowMedium;
    return secPerArrowEasy;
  }

  /// Calculates deterministic time limit in seconds from arrow count and level.
  /// limit = round(N * secPerArrow(tier)).clamp(45, 600).
  static int computeTimeLimitSeconds(int arrowCount, int levelId) {
    final secPerArrow = secPerArrowForLevel(levelId);
    final raw = (arrowCount * secPerArrow).round();
    return raw.clamp(minTimeLimitSeconds, maxTimeLimitSeconds);
  }

  /// Determines stars from mistakes, time used, total limit, and relaxed mode.
  /// - Relaxed mode: timer disabled, max 2 stars.
  /// - Normal mode:
  ///   - 3 stars: 0 mistakes AND timeLeft >= 30% of limit
  ///   - 2 stars: mistakes <= 1 OR finished with any time left (> 0)
  ///   - 1 star: otherwise
  static int computeStars({
    required int mistakes,
    required int timeLeftSeconds,
    required int limitSeconds,
    required bool relaxedMode,
  }) {
    if (relaxedMode) {
      if (mistakes == 0) return 2;
      return 1;
    }
    if (mistakes == 0 && timeLeftSeconds >= (limitSeconds * 0.30).ceil()) {
      return 3;
    }
    if (mistakes <= 1 || timeLeftSeconds > 0) {
      return 2;
    }
    return 1;
  }
}
