import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';

void main() {
  group('Countdown Timer DifficultyConfig tests', () {
    test('Limit calculation per tier', () {
      // Easy tier (level 1-5, e.g. 25 arrows * 6.0 = 150s)
      final easyLimit = DifficultyConfig.computeTimeLimitSeconds(25, 3);
      expect(easyLimit, 150);

      // Medium tier (level 6-12, e.g. 30 arrows * 5.0 = 150s)
      final medLimit = DifficultyConfig.computeTimeLimitSeconds(30, 8);
      expect(medLimit, 150);

      // Hard tier (level 13-19, e.g. 40 arrows * 4.0 = 160s)
      final hardLimit = DifficultyConfig.computeTimeLimitSeconds(40, 15);
      expect(hardLimit, 160);

      // Boss tier (level 20, e.g. 50 arrows * 3.5 = 175s)
      final bossLimit = DifficultyConfig.computeTimeLimitSeconds(50, 20);
      expect(bossLimit, 175);
    });

    test('Min and max clamps (45s min, 600s max)', () {
      // Very small arrow count clamped to 45s
      final lowClamp = DifficultyConfig.computeTimeLimitSeconds(4, 20);
      expect(lowClamp, 45);

      // Huge board clamped to 600s
      final highClamp = DifficultyConfig.computeTimeLimitSeconds(250, 1);
      expect(highClamp, 600);
    });

    test('Star calculation rules', () {
      // 3 stars: 0 mistakes and timeLeft >= 30% of limit (e.g. 30s left of 100s)
      expect(
        DifficultyConfig.computeStars(
          mistakes: 0,
          timeLeftSeconds: 30,
          limitSeconds: 100,
          relaxedMode: false,
        ),
        3,
      );

      // 2 stars: 0 mistakes but timeLeft < 30% (e.g. 10s left of 100s)
      expect(
        DifficultyConfig.computeStars(
          mistakes: 0,
          timeLeftSeconds: 10,
          limitSeconds: 100,
          relaxedMode: false,
        ),
        2,
      );

      // 2 stars: 1 mistake with time left
      expect(
        DifficultyConfig.computeStars(
          mistakes: 1,
          timeLeftSeconds: 40,
          limitSeconds: 100,
          relaxedMode: false,
        ),
        2,
      );

      // 1 star: 2 mistakes and finished with 0 time left
      expect(
        DifficultyConfig.computeStars(
          mistakes: 2,
          timeLeftSeconds: 0,
          limitSeconds: 100,
          relaxedMode: false,
        ),
        1,
      );

      // Relaxed mode: capped at 2 stars for perfect solve, 1 otherwise
      expect(
        DifficultyConfig.computeStars(
          mistakes: 0,
          timeLeftSeconds: 90,
          limitSeconds: 100,
          relaxedMode: true,
        ),
        2,
      );
      expect(
        DifficultyConfig.computeStars(
          mistakes: 1,
          timeLeftSeconds: 90,
          limitSeconds: 100,
          relaxedMode: true,
        ),
        1,
      );
    });
  });
}

