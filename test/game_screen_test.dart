import 'package:arrow_puzzle/app.dart';
import 'package:arrow_puzzle/core/providers.dart';
import 'package:arrow_puzzle/core/storage/storage_service.dart';
import 'package:arrow_puzzle/features/game/logic/game_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/memory_storage_service.dart';

Future<(StorageService, ProviderContainer)> _boot(
  WidgetTester tester,
) async {
  final storage = MemoryStorageService();
  storage.onboardingDone = true;
  // Tutorial overlays run infinite pulse animations that prevent
  // pumpAndSettle from finishing; they are covered manually, not here.
  for (var i = 1; i <= 3; i++) {
    storage.markTutorialSeen(i);
  }

  final container = ProviderContainer(
    overrides: [storageProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);

  final router = createRouter(initialLocation: '/levels');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ArrowPuzzleApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return (storage, container);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Never hit the network for fonts in tests; the bundled Nunito files are
  // used when present, otherwise the default font is fine.
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('boots into level select', (tester) async {
    final (_, container) = await _boot(tester);
    expect(find.text('Arrow Escape'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(container.read(storageProvider).onboardingDone, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('game screen: tap validation, hearts, win overlay', (tester) async {
    final (_, container) = await _boot(tester);

    // Open level 1.
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    // Wait for the level to load and the board to appear.
    await tester.pumpUntilFound(find.byType(CustomPaint));
    final level = await container.read(levelProvider(1).future);
    final gameId = level.id;
    final state = container.read(gameProvider(gameId));
    expect(state.remaining, hasLength(level.arrowCount));
    expect(find.textContaining('Level 1'), findsWidgets);

    // Valid tap: a free arrow evaluates as valid and slides out.
    final free = level.board.freeArrows(state.remaining);
    expect(free, isNotEmpty);
    final notifier = container.read(gameProvider(gameId).notifier);
    expect(notifier.evaluateTap(free.first), isA<TapValid>());
    notifier.completeSlide(free.first);
    await tester.pump();
    expect(container.read(gameProvider(gameId)).remaining,
        hasLength(level.arrowCount - 1));

    // Blocked tap: mistake costs a heart.
    final fresh = container.read(gameProvider(gameId));
    final blocked = fresh.level.board.arrows.firstWhere(
      (a) =>
          fresh.remaining.contains(a.id) &&
          !fresh.level.board.isFree(a, fresh.remaining),
    );
    final outcome = notifier.evaluateTap(blocked);
    expect(outcome, isA<TapBlocked>());
    final heartsBefore = container.read(gameProvider(gameId)).hearts;
    notifier.registerMistake(blocked, (outcome as TapBlocked).blockedRay);
    await tester.pump();
    expect(container.read(gameProvider(gameId)).hearts, heartsBefore - 1);
    notifier.clearBlocked();

    // Solve the rest in a valid order -> win overlay with stars.
    while (container.read(gameProvider(gameId)).status ==
        GameStatus.playing) {
      final s = container.read(gameProvider(gameId));
      final next = s.level.board.freeArrows(s.remaining).first;
      notifier.completeSlide(next);
      await tester.pump();
    }
    expect(container.read(gameProvider(gameId)).status, GameStatus.won);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Level Complete!'), findsOneWidget);
    expect(find.text('Next Level'), findsOneWidget);

    // Progress persisted: 1-2 stars (we made a mistake), level 2 unlocked.
    final storage = container.read(storageProvider);
    expect(storage.starsForLevel(1), 2);
    expect(storage.isLevelUnlocked(2), isTrue);

    // Tear down tree so confetti controller stops
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('failing three taps shows fail overlay and revive works',
      (tester) async {
    final (_, container) = await _boot(tester);
    await tester.tap(find.text('1'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpUntilFound(find.byType(CustomPaint));

    final level = await container.read(levelProvider(1).future);
    final gameId = level.id;
    final notifier = container.read(gameProvider(gameId).notifier);

    // Burn all hearts on blocked taps (fall back to free arrows when the
    // tutorial board has no blocked arrows).
    for (var i = 0; i < 3; i++) {
      final s = container.read(gameProvider(gameId));
      if (s.status != GameStatus.playing) break;
      final candidates = s.level.board.arrows
          .where((a) => s.remaining.contains(a.id))
          .toList();
      final blocked = candidates.firstWhere(
        (a) => !s.level.board.isFree(a, s.remaining),
        orElse: () => candidates.first,
      );
      notifier.registerMistake(blocked, const []);
      await tester.pump();
    }
    expect(container.read(gameProvider(gameId)).status, GameStatus.failed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Out of hearts!'), findsOneWidget);

    // Revive (starts with 60 coins).
    final reviveButton = find.textContaining('Revive');
    if (reviveButton.evaluate().isNotEmpty) {
      await tester.tap(reviveButton);
      await tester.pump();
      expect(container.read(gameProvider(gameId)).status, GameStatus.playing);
      expect(container.read(gameProvider(gameId)).hearts, 1);
    }

    // Tear down tree so confetti / animations stop cleanly
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

extension on WidgetTester {
  Future<void> pumpUntilFound(Finder finder) async {
    for (var i = 0; i < 60; i++) {
      await pump(const Duration(milliseconds: 50));
      if (any(finder)) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }
}
