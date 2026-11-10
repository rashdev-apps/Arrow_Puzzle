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
  static const int maxArrowCap = 250;
  static const int mistakePenaltySeconds = 3;
  static const int freezePowerupCost = 20;
  static const int freezePowerupSeconds = 10;
  static const int reviveSecondsBonus = 15;

  /// High-volume difficulty target ranges:
  /// - Test levels 1-6: Heart (30), Dog (50), Cat (60), Elephant (80), Butterfly (100), Maze (120)
  /// - Beginner (L1-15): 20–35 arrows
  /// - Easy (L16-30): 35–55 arrows
  /// - Medium (L31-50): 55–85 arrows
  /// - Hard (L51-70): 85–125 arrows
  /// - Expert (L71-100): 125–180 arrows
  /// - Master (L101+): 180–250 arrows
  static const List<(int level, int count)> anchors = [
    (1, 30),   // Heart
    (2, 50),   // Dog
    (3, 60),   // Cat
    (4, 80),   // Elephant
    (5, 100),  // Butterfly
    (6, 120),  // Complex Maze
    (10, 35),
    (20, 50),
    (35, 75),
    (50, 100),
    (75, 150),
    (100, 180),
    (150, 220),
    (200, 250),
  ];

  static int baselineArrowCount(int level) {
    if (level <= 1) return 30;
    if (level <= 6) {
      // Exact test levels as specified:
      return switch (level) {
        1 => 30,  // Heart
        2 => 50,  // Dog
        3 => 60,  // Cat
        4 => 80,  // Elephant
        5 => 100, // Butterfly
        6 => 120, // Complex maze
        _ => 30,
      };
    }
    if (level >= 200) {
      return maxArrowCap;
    }
    for (var i = 5; i < anchors.length - 1; i++) {
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

