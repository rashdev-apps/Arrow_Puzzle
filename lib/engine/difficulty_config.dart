import 'dart:math';

enum DifficultyTier {
  easy('Easy', 6.0),
  medium('Medium', 5.0),
  hard('Hard', 4.0),
  expert('Expert', 3.5);

  final String label;
  final double secPerArrow;
  const DifficultyTier(this.label, this.secPerArrow);
}

class DifficultyConfig {
  static const int maxArrowCap = 220;
  static const int mistakePenaltySeconds = 3;
  static const int freezePowerupCost = 20;
  static const int freezePowerupSeconds = 10;
  static const int reviveSecondsBonus = 15;

  static const List<(int level, int count)> anchors = [
    (1, 4),
    (2, 6),
    (3, 8),
    (5, 12),
    (8, 16),
    (12, 24),
    (20, 36),
    (35, 56),
    (50, 80),
    (75, 110),
    (100, 140),
    (150, 180),
  ];

  static int baselineArrowCount(int level) {
    if (level <= 1) return 4;
    if (level >= 150) {
      final extra = ((level - 150) * 0.4).round();
      return min(maxArrowCap, 180 + extra);
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

  static int arrowCount(int level) {
    final base = baselineArrowCount(level);
    if (level > 0 && level % 10 == 0) {
      // Boss level: +10% arrows
      return min(maxArrowCap, (base * 1.10).round());
    } else if (level > 1 && (level - 1) % 10 == 0) {
      // Breather level: ~5% easier than its raw baseline
      final prevBase = baselineArrowCount(level - 1);
      final breather = (base * 0.95).round();
      return max(prevBase, breather);
    }
    return base;
  }

  static bool isBossLevel(int level) => level > 0 && level % 10 == 0;

  static DifficultyTier tierForLevel(int level) {
    if (level <= 10) return DifficultyTier.easy;
    if (level <= 30) return DifficultyTier.medium;
    if (level <= 70) return DifficultyTier.hard;
    return DifficultyTier.expert;
  }

  static int? computeTimeLimitSeconds(int arrows, int level) {
    if (level <= 3) return null; // No timer on levels 1-3
    final tier = tierForLevel(level);
    final raw = (arrows * tier.secPerArrow).round();
    return raw.clamp(20, 900);
  }

  static int maxFreePerStep(int level) {
    if (level <= 10) return 3;
    if (level <= 30) return 2;
    return 1;
  }

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
    final ratio = timeLeftSeconds / limitSeconds;
    if (mistakes == 0 && ratio >= 0.30) return 3;
    if (mistakes <= 1 || ratio >= 0.05) return 2;
    return 1;
  }
}

