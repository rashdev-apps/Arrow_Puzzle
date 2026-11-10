import 'dart:math';

import '../domain/arrow.dart';
import '../domain/board.dart';
import 'solver.dart';

enum DifficultyTier {
  easy('Easy', 6.0),
  medium('Medium', 5.0),
  hard('Hard', 4.0),
  expert('Expert', 3.5);

  final String label;
  final double secPerArrow;
  const DifficultyTier(this.label, this.secPerArrow);
}

class BoardDimension {
  final int rows;
  final int cols;
  const BoardDimension(this.rows, this.cols);

  int get cellCount => rows * cols;
}

class DifficultyConfig {
  static const List<(int level, int count)> anchors = [
    (1, 4),
    (2, 6),
    (3, 8),
    (4, 10),
    (5, 12),
    (8, 16),
    (12, 24),
    (20, 36),
    (35, 52),
    (50, 68),
    (75, 90),
    (100, 110),
  ];

  static const int maxArrowCap = 120;
  static const int mistakePenaltySeconds = 3;
  static const int freezePowerupCost = 20;
  static const int freezePowerupSeconds = 10;
  static const int reviveSecondsBonus = 15;

  /// Pure baseline monotonically increasing curve before sawtooth.
  static int baselineArrowCount(int level) {
    if (level <= 1) return 4;
    if (level >= 100) {
      // Scale from 110 at level 100 up to cap 120 at level 150+
      final extra = ((level - 100) * 0.2).round();
      return min(maxArrowCap, 110 + extra);
    }

    for (var i = 0; i < anchors.length - 1; i++) {
      final (l1, c1) = anchors[i];
      final (l2, c2) = anchors[i + 1];
      if (level >= l1 && level <= l2) {
        final t = (level - l1) / (l2 - l1);
        final interp = c1 + t * (c2 - c1);
        return interp.round();
      }
    }
    return maxArrowCap;
  }

  /// Exact arrow count curve with boss/breather sawtooth applied:
  /// - Every 10th level is a "boss" (+10% arrows).
  /// - The level after a boss is a "breather" (~5% easier than its raw baseline).
  /// - Monotonic progression guaranteed across anchors.
  static int arrowCount(int level) {
    final base = baselineArrowCount(level);
    if (level % 10 == 0) {
      // Boss level
      return min(maxArrowCap, (base * 1.10).round());
    } else if (level > 1 && (level - 1) % 10 == 0) {
      // Breather level right after boss
      final prevBase = baselineArrowCount(level - 1);
      final breather = (base * 0.95).round();
      // Keep at least equal or slightly greater than previous base so it never drops below previous anchor baseline
      return max(prevBase, breather);
    }
    return base;
  }

  static bool isBossLevel(int level) => level > 0 && level % 10 == 0;

  static DifficultyTier tierForLevel(int level) {
    if (level <= 10) return DifficultyTier.easy;
    if (level <= 30) return DifficultyTier.medium;
    if (level <= 60) return DifficultyTier.hard;
    return DifficultyTier.expert;
  }

  /// Returns (tier, isBoss) display info.
  static String difficultyLabel(int level) {
    final tier = tierForLevel(level);
    if (isBossLevel(level)) {
      return '${tier.label} • Boss';
    }
    return tier.label;
  }

  /// Board dimensions (rows x cols) computed from arrow count so coverage >= 90%.
  /// Allows pleasant aspect ratios for portrait phone screens (e.g. 5x5, 6x8, 8x10, etc.).
  static BoardDimension boardSizeFor(int level, int arrowCount) {
    // Average segments per arrow range from ~2.2 at start to ~3.2 in later levels
    final avgSegments = level <= 5 ? 2.3 : (level <= 20 ? 2.6 : 3.0);
    final neededCells = (arrowCount * avgSegments / 0.92).ceil();

    // Target portrait ratio around 1.1 - 1.35 (rows >= cols)
    int bestRows = 5;
    int bestCols = 5;
    double bestDiff = 999999;

    for (var cols = 4; cols <= 30; cols++) {
      for (var rows = cols; rows <= (cols * 1.4).ceil() + 1; rows++) {
        final total = rows * cols;
        if (total >= neededCells) {
          final coverage = (arrowCount * avgSegments) / total;
          if (coverage >= 0.85 && coverage <= 1.05) {
            final diff = (total - neededCells).abs();
            if (diff < bestDiff) {
              bestDiff = diff.toDouble();
              bestRows = rows;
              bestCols = cols;
            }
          }
        }
      }
    }

    // Safety fallback
    if (bestRows * bestCols < neededCells) {
      bestCols = (sqrt(neededCells) * 0.9).floor().clamp(5, 30);
      bestRows = (neededCells / bestCols).ceil().clamp(5, 36);
    }

    return BoardDimension(bestRows, bestCols);
  }

  /// Timer limit in seconds:
  /// First 3 levels have NO timer (null).
  /// Other levels = max(20, (arrows * secPerArrow(tier)).round()).
  static int? computeTimeLimitSeconds(int arrows, int level) {
    if (level <= 3) return null;
    final tier = tierForLevel(level);
    final raw = (arrows * tier.secPerArrow).round();
    return max(20, raw);
  }

  /// Scaled parameters for chain-puzzle generator knobs per level
  static int maxFreeWave(int level) {
    if (level <= 10) return 3;
    if (level <= 30) return 2;
    return 1;
  }

  static int minTrailDistance(int level) {
    if (level <= 5) return 2;
    if (level <= 20) return 4;
    return 6;
  }

  /// Calculates stars earned (1..3) based on mistakes and time left
  static int computeStars({
    required int mistakes,
    required int timeLeftSeconds,
    required int limitSeconds,
    required bool relaxedMode,
  }) {
    if (mistakes > 2) return 1;
    if (relaxedMode || limitSeconds <= 0) {
      if (mistakes == 0) return 3;
      if (mistakes <= 1) return 2;
      return 1;
    }
    // With timer active:
    final timeRatio = timeLeftSeconds / limitSeconds;
    if (mistakes == 0 && timeRatio >= 0.3) return 3;
    if (mistakes <= 1 && timeRatio >= 0.1) return 2;
    return 1;
  }
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

  bool isValidFor(int levelId) {
    if (!isSolvable) return false;
    if (coverage < 0.82) return false;

    final allowedMaxFree = DifficultyConfig.maxFreeWave(levelId);
    if (maxFreeWave > allowedMaxFree) return false;

    if (levelId > 30 && !isForcedOrder && maxFreeWave > 2) return false;

    return true;
  }

  static BoardQualityMetrics evaluate(
    Board board, {
    Solver solver = const Solver(),
  }) {
    final arrows = board.arrows;
    final N = arrows.length;
    if (N == 0) {
      return const BoardQualityMetrics(
        arrowCount: 0,
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

    final occupiedCount = board.arrows.fold<int>(0, (sum, a) => sum + a.path.length);
    final activeCount = board.mask.where((m) => m).length;
    final coverage = activeCount == 0 ? 0.0 : occupiedCount / activeCount;

    final analysis = solver.analyze(board);
    final isSolvable = analysis.isSolvable;
    final longestChain = analysis.longestChain;
    final depthRatio = longestChain / N;

    final freeAtStart = analysis.freeAtStart;
    final free0Ratio = freeAtStart / N;

    int totalRayBlockers = 0;
    int multiBlockerCount = 0;
    int decoyCount = 0;

    for (final entry in analysis.dependencyGraph.entries) {
      final blockers = entry.value.length;
      totalRayBlockers += blockers;
      if (blockers >= 2) multiBlockerCount++;
      if (blockers == 1) decoyCount++;
    }

    final avgRayBlockers = totalRayBlockers / N;
    final multiBlockerRatio = multiBlockerCount / N;

    // Estimate winding ratio from average arrow path length
    final windingRatio = (analysis.averagePathLength - 1.0).clamp(0.0, 5.0);
    final maxFreeWave = freeAtStart;
    final maxFreeWaveRatio = maxFreeWave / N;
    final avgFree = freeAtStart.toDouble();
    final isForcedOrder = freeAtStart <= 3;

    final score = (depthRatio * 35.0) +
        ((1.0 - (maxFreeWaveRatio.clamp(0.0, 1.0))) * 25.0) +
        (avgRayBlockers * 15.0) +
        (windingRatio * 15.0) +
        (coverage * 10.0);

    return BoardQualityMetrics(
      arrowCount: N,
      free0: freeAtStart,
      free0Ratio: free0Ratio,
      longestChain: longestChain,
      depthRatio: depthRatio,
      avgRayBlockers: avgRayBlockers,
      multiBlockerRatio: multiBlockerRatio,
      maxFreeWave: maxFreeWave,
      maxFreeWaveRatio: maxFreeWaveRatio,
      avgFree: avgFree,
      decoyCount: decoyCount,
      coverage: coverage,
      windingRatio: windingRatio,
      difficultyScore: score,
      isSolvable: isSolvable,
      isForcedOrder: isForcedOrder,
    );
  }
}
