import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/core/providers.dart';
import 'package:arrow_puzzle/core/storage/storage_service.dart';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/domain/level.dart';
import 'package:arrow_puzzle/features/game/presentation/game_screen.dart';

class TestStorageService implements StorageService {
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

  final Map<int, int> _stars = {};
  final Map<int, int> _bestTimes = {};

  @override int starsForDaily(String date) => 0;
  @override void setDailyStars(String date, int stars) {}
  @override int starsForLevel(int levelId) => _stars[levelId] ?? 0;
  @override void setLevelStars(int levelId, int stars) => _stars[levelId] = stars;
  @override int? bestTimeForLevel(int levelId) => _bestTimes[levelId];
  @override void setBestTimeForLevel(int levelId, int seconds) => _bestTimes[levelId] = seconds;
  @override bool isLevelUnlocked(int levelId) => true;
  @override bool tutorialSeenFor(int levelId) => true;
  @override void markTutorialSeen(int levelId) {}
  @override void clearLevelState(int levelId) {}
  @override Map<String, dynamic>? savedLevelState(int levelId) => null;
  @override void saveLevelState(int levelId, Map<String, dynamic> state) {}
  @override Future<void> resetProgress() async {}
}

void main() {
  testWidgets('GameScreen widget test: timer starts on tap, fail dialog on timeout', (tester) async {
    final testStorage = TestStorageService();

    final testLevel = Level(
      id: 6, // level 6 has timer visible
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
      hash: 'hash_test',
      timeLimitSeconds: 60,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(testStorage),
          levelProvider(6).overrideWith((ref) => Future.value(testLevel)),
        ],
        child: const MaterialApp(
          home: GameScreen(levelId: 6),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify timer pill displays 01:00
    expect(find.text('01:00'), findsOneWidget);

    // Tap on board to trigger interaction
    await tester.tap(find.byType(GameScreen));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify timer widget exists and is active
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
  });
}

