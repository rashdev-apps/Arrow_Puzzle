import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/core/ads/ad_service.dart';
import 'package:arrow_puzzle/core/providers.dart';
import 'package:arrow_puzzle/core/storage/storage_service.dart';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/domain/level.dart';
import 'package:arrow_puzzle/features/game/presentation/game_screen.dart';

class TestStorage implements StorageService {
  @override bool soundOn = false;
  @override bool musicOn = false;
  @override bool hapticsOn = false;
  @override bool colorblindMode = false;
  @override bool relaxedMode = false;
  @override String themeId = 'classic';
  @override bool onboardingDone = true;
  @override int coins = 0;
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
  testWidgets('Game screen shows out-of-lives dialog and Watch ad button', (tester) async {
    final storage = TestStorage();
    final fakeAdService = FakeAdService(shouldGrantReward: true);

    final testLevel = Level(
      id: 6,
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
        ],
      ),
      parMoves: 1,
      difficulty: 0.5,
      hash: 'hash_ad_test',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage),
          adServiceProvider.overrideWithValue(fakeAdService),
          levelProvider(6).overrideWith((ref) => Future.value(testLevel)),
        ],
        child: const MaterialApp(
          home: GameScreen(levelId: 6),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify hint button starts with FREE badge and shows free count
    expect(find.text('Hint (2 free)'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);

    // Verify no banner ad overlaps board area
    expect(find.byType(AdBannerWidget), findsNothing);
  });
}

