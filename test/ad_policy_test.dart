import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/core/ads/ad_config.dart';
import 'package:arrow_puzzle/core/ads/ad_service.dart';
import 'package:arrow_puzzle/core/storage/storage_service.dart';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/domain/level.dart';
import 'package:arrow_puzzle/features/game/logic/game_notifier.dart';

class TestStorage implements StorageService {
  @override bool soundOn = false;
  @override bool musicOn = false;
  @override bool hapticsOn = false;
  @override bool colorblindMode = false;
  @override bool relaxedMode = false;
  @override String themeId = 'classic';
  @override bool onboardingDone = true;
  @override int coins = 100;
  @override int totalArrowsRemoved = 0;
  @override int levelsCompleted = 0;
  @override int bestStreak = 0;
  @override List<String> ownedThemes = ['classic'];
  @override String? lastDailyDate;
  @override int dailyStreak = 0;

  @override int starsForDaily(String date) => 0;
  @override void setDailyStars(String date, int stars) {}
  @override int starsForLevel(int levelId) => 0;
  @override void setLevelStars(int levelId, int stars) {}
  @override int? bestTimeForLevel(int levelId) => null;
  @override void setBestTimeForLevel(int levelId, int seconds) {}
  @override bool isLevelUnlocked(int levelId) => true;
  @override bool tutorialSeenFor(int levelId) => true;
  @override void markTutorialSeen(int levelId) {}
  @override void clearLevelState(int levelId) {}
  @override Map<String, dynamic>? savedLevelState(int levelId) => null;
  @override void saveLevelState(int levelId, Map<String, dynamic> state) {}
  @override Future<void> resetProgress() async {}
}

void main() {
  late Level testLevel;
  late TestStorage storage;

  setUp(() {
    storage = TestStorage();
    testLevel = Level(
      id: 1,
      shape: 'square',
      board: Board(
        rows: 4,
        cols: 4,
        mask: List.filled(16, true),
        arrows: [
          Arrow(
            id: 'a0',
            path: const [GridCell(0, 0), GridCell(0, 1)],
            dir: Direction.right,
          ),
          Arrow(
            id: 'a1',
            path: const [GridCell(1, 0), GridCell(1, 1)],
            dir: Direction.right,
          ),
        ],
      ),
      parMoves: 2,
      difficulty: 0.5,
      hash: 'hash',
    );
  });

  group('Rewarded Ads Game Logic & Policy Tests', () {
    test('Max hints and free hints policy enforcement', () {
      final notifier = GameNotifier(level: testLevel, storage: storage);
      expect(notifier.state.hintsUsed, 0);
      expect(AdConfig.freeHintsPerLevel, 2);
      expect(AdConfig.maxHintsPerLevel, 5);

      // Free Hint 1
      expect(notifier.state.hintsUsed < AdConfig.freeHintsPerLevel, isTrue);
      final h1 = notifier.useHint();
      expect(h1, isNotNull);
      expect(notifier.state.hintsUsed, 1);

      // Free Hint 2
      expect(notifier.state.hintsUsed < AdConfig.freeHintsPerLevel, isTrue);
      final h2 = notifier.useHint();
      expect(h2, isNotNull);
      expect(notifier.state.hintsUsed, 2);

      // Now free hints are exhausted, subsequent hints require ad
      expect(notifier.state.hintsUsed >= AdConfig.freeHintsPerLevel, isTrue);
    });

    test('Revive restores configured hearts (2 hearts) and increments revivesUsed', () {
      final notifier = GameNotifier(level: testLevel, storage: storage);

      // Deplete hearts to trigger fail
      notifier.registerMistake(testLevel.board.arrows.first, []);
      notifier.registerMistake(testLevel.board.arrows.first, []);
      notifier.registerMistake(testLevel.board.arrows.first, []);
      expect(notifier.state.status, GameStatus.failed);
      expect(notifier.state.revivesUsed, 0);

      // Revive with ad policy (restores 2 hearts)
      notifier.revive(heartsRestored: AdConfig.heartsRestoredOnRevive);
      expect(notifier.state.status, GameStatus.playing);
      expect(notifier.state.hearts, 2);
      expect(notifier.state.revivesUsed, 1);

      // Max 1 revive per level attempt policy
      expect(notifier.state.revivesUsed >= AdConfig.maxRevivesPerLevel, isTrue);
    });

    test('FakeAdService grants reward only when shouldGrantReward is true', () async {
      final adServiceSuccess = FakeAdService(shouldGrantReward: true);
      final success = await adServiceSuccess.showRewarded(purpose: AdPurpose.hint);
      expect(success, isTrue);

      final adServiceDismissed = FakeAdService(shouldGrantReward: false);
      final dismissed = await adServiceDismissed.showRewarded(purpose: AdPurpose.hint);
      expect(dismissed, isFalse);
    });
  });
}

