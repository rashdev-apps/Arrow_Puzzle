import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_config.dart';
import '../../../core/ads/ad_service.dart';
import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../levels/data/level_repository.dart';
import '../logic/difficulty_config.dart';
import '../logic/game_notifier.dart';
import '../logic/level_timer_notifier.dart';
import 'board_view.dart';
import 'level_timer_pill.dart';

class GameScreen extends ConsumerStatefulWidget {
  final int levelId;
  final bool daily;

  const GameScreen({
    super.key,
    required this.levelId,
    this.daily = false,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  final GlobalKey<BoardViewState> _boardKey = GlobalKey();
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );
  bool _winHandled = false;
  int _gameId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confetti.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_gameId != 0) {
      final timerNotifier = ref.read(levelTimerProvider(_gameId).notifier);
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        timerNotifier.pause();
      } else if (state == AppLifecycleState.resumed) {
        timerNotifier.resume();
      }
    }
  }

  void _onFirstInteraction() {
    if (_gameId != 0) {
      ref.read(levelTimerProvider(_gameId).notifier).start();
    }
  }

  Future<void> _onHint() async {
    final game = ref.read(gameProvider(_gameId));
    if (game.hintsUsed >= AdConfig.maxHintsPerLevel) {
      _showSnack('Maximum hints reached for this level.');
      return;
    }

    final audio = ref.read(audioProvider);
    final notifier = ref.read(gameProvider(_gameId).notifier);

    // First 2 hints are free!
    if (game.hintsUsed < AdConfig.freeHintsPerLevel) {
      final id = notifier.useHint();
      if (id == null) return;
      audio.click();
      ref.read(hapticsProvider).selection();
      final left = AdConfig.freeHintsPerLevel - game.hintsUsed - 1;
      _showSnack('Free hint used! ($left free remaining)');
      return;
    }

    // After 2 free hints, watch a rewarded ad to unlock subsequent hints
    final timerNotifier = ref.read(levelTimerProvider(_gameId).notifier);
    timerNotifier.pause();

    final adService = ref.read(adServiceProvider);
    final rewarded = await adService.showRewarded(
      purpose: AdPurpose.hint,
      context: context,
    );
    timerNotifier.resume();

    if (!rewarded) {
      _showSnack('Ad not completed. Hint not unlocked.');
      return;
    }

    final id = notifier.useHint();
    if (id == null) return;
    audio.click();
    ref.read(hapticsProvider).selection();
    _showSnack('Hint unlocked via Ad!');
  }

  void _onUndo() {
    final notifier = ref.read(gameProvider(_gameId).notifier);
    final arrow = notifier.undo();
    if (arrow == null) {
      _showSnack('No undos left — they cost ${AppConstants.undoCost} coins.');
      return;
    }
    ref.read(audioProvider).click();
    ref.read(hapticsProvider).selection();
    _boardKey.currentState?.playUndoSlide(arrow);
  }

  void _onRestart() {
    ref.read(gameProvider(_gameId).notifier).restart();
    ref.read(levelTimerProvider(_gameId).notifier).reset();
    _winHandled = false;
    ref.read(audioProvider).click();
  }

  void _onFreezeTime() {
    final coins = ref.read(profileProvider).coins;
    if (coins < DifficultyConfig.freezePowerupCost) {
      _showSnack('Need ${DifficultyConfig.freezePowerupCost} coins to freeze time.');
      return;
    }
    ref.read(profileProvider.notifier).spendCoins(DifficultyConfig.freezePowerupCost);
    ref.read(levelTimerProvider(_gameId).notifier).freezeTime(DifficultyConfig.freezePowerupSeconds);
    ref.read(audioProvider).click();
    ref.read(hapticsProvider).light();
    _showSnack('Time frozen for ${DifficultyConfig.freezePowerupSeconds}s!');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final levelAsync = widget.daily
        ? ref.watch(dailyLevelProvider)
        : ref.watch(levelProvider(widget.levelId));

    return levelAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Failed to load level: $e'))),
      data: (level) {
        final gameId = level.id;
        _gameId = gameId;

        // Listen for timeout from LevelTimerNotifier
        ref.listen<TimerState>(levelTimerProvider(gameId), (prev, next) {
          if (next.isTimeout && (prev == null || !prev.isTimeout)) {
            ref.read(gameProvider(gameId).notifier).handleTimeout();
          }
        });

        ref.listen<GameState>(gameProvider(gameId), (prev, next) {
          // Penalty in timer when mistake happens (blocked tap)
          if (next.mistakes > (prev?.mistakes ?? 0)) {
            ref.read(levelTimerProvider(gameId).notifier).applyMistakePenalty();
          }

          if (next.status == GameStatus.won && !_winHandled) {
            _winHandled = true;
            final timerNotifier = ref.read(levelTimerProvider(gameId).notifier);
            final timerState = ref.read(levelTimerProvider(gameId));
            timerNotifier.stopOnWin();

            // Finalize stars with timer stats
            final relaxed = ref.read(settingsProvider).relaxedMode;
            ref.read(gameProvider(gameId).notifier).finalizeWin(
                  timeLeftSeconds: timerState.remainingSeconds,
                  limitSeconds: timerState.totalLimitSeconds,
                  relaxedMode: relaxed,
                );

            ref.read(audioProvider).win();
            ref.read(hapticsProvider).medium();
            _confetti.play();
            _onWin(ref.read(gameProvider(gameId)));
          }
          if (next.status == GameStatus.failed &&
              prev?.status != GameStatus.failed) {
            ref.read(levelTimerProvider(gameId).notifier).pause();
            ref.read(audioProvider).heartLost();
            ref.read(hapticsProvider).error();
          }
        });

        final game = ref.watch(gameProvider(gameId));
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _TopBar(levelId: gameId, daily: widget.daily),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: BoardView(
                          key: _boardKey,
                          level: level,
                          onFirstInteraction: _onFirstInteraction,
                        ),
                      ),
                    ),
                    _BottomBar(
                      onHint: _onHint,
                      onUndo: _onUndo,
                      onRestart: _onRestart,
                      onFreezeTime: _onFreezeTime,
                      isFrozen: ref.watch(levelTimerProvider(gameId)).isFrozen,
                      hintsUsed: game.hintsUsed,
                    ),
                  ],
                ),
                if (game.status == GameStatus.won)
                  _WinOverlay(
                    levelId: gameId,
                    stars: game.starsEarned,
                    confetti: _confetti,
                    daily: widget.daily,
                  ),
                if (game.status == GameStatus.failed)
                  _FailOverlay(levelId: gameId),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onWin(GameState state) {
    ref.read(profileProvider.notifier).refresh();
    if (!widget.daily) return;
    final storage = ref.read(storageProvider);
    final today = DateTime.now();
    final todayKey = LevelRepository.dailyKeyString(today);
    final yesterday = today.subtract(const Duration(days: 1));
    storage.setDailyStars(todayKey, state.starsEarned);
    if (storage.lastDailyDate != todayKey) {
      storage.dailyStreak =
          storage.lastDailyDate == LevelRepository.dailyKeyString(yesterday)
              ? storage.dailyStreak + 1
              : 1;
      if (storage.dailyStreak > storage.bestStreak) {
        storage.bestStreak = storage.dailyStreak;
      }
      storage.lastDailyDate = todayKey;
    }
  }
}

class _TopBar extends ConsumerWidget {
  final int levelId;
  final bool daily;

  const _TopBar({required this.levelId, this.daily = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider(levelId));
    final profile = ref.watch(profileProvider);
    final theme = ref.watch(settingsProvider).theme;

    final title = daily
        ? 'Daily · ${game.level.shape[0].toUpperCase()}${game.level.shape.substring(1)}'
        : 'Level $levelId · ${game.level.shape[0].toUpperCase()}${game.level.shape.substring(1)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/levels');
                  }
                },
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < AppConstants.heartsPerLevel; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(
                        i < game.hearts
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: i < game.hearts
                            ? AppConstants.red
                            : theme.textColor.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              _CoinChip(coins: profile.coins),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          // Prominent center countdown timer pill
          Center(
            child: LevelTimerPill(levelId: levelId),
          ),
        ],
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  final int coins;

  const _CoinChip({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppConstants.gold.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              size: 16, color: AppConstants.gold),
          const SizedBox(width: 3),
          Text('$coins', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  final VoidCallback onHint;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final VoidCallback onFreezeTime;
  final bool isFrozen;
  final int hintsUsed;

  const _BottomBar({
    required this.onHint,
    required this.onUndo,
    required this.onRestart,
    required this.onFreezeTime,
    required this.isFrozen,
    required this.hintsUsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider).theme;
    final isFree = hintsUsed < AdConfig.freeHintsPerLevel;
    final freeLeft = AdConfig.freeHintsPerLevel - hintsUsed;
    final totalLeft = (AdConfig.maxHintsPerLevel - hintsUsed).clamp(0, AdConfig.maxHintsPerLevel);

    final String hintLabel;
    final String? badgeText;

    if (isFree) {
      hintLabel = 'Hint ($freeLeft free)';
      badgeText = 'FREE';
    } else if (totalLeft > 0) {
      hintLabel = 'Hint ($totalLeft left)';
      badgeText = 'AD';
    } else {
      hintLabel = 'Hint (0)';
      badgeText = null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BarButton(
            icon: Icons.lightbulb_outline_rounded,
            label: hintLabel,
            badgeText: badgeText,
            color: totalLeft > 0 ? theme.arrowHint : Colors.grey,
            onTap: totalLeft > 0 ? onHint : () {},
          ),
          _BarButton(
            icon: Icons.ac_unit_rounded,
            label: isFrozen ? 'Frozen' : 'Freeze 10s',
            color: isFrozen ? AppConstants.blue : theme.arrowColor,
            onTap: onFreezeTime,
          ),
          _BarButton(
            icon: Icons.undo_rounded,
            label: 'Undo',
            color: theme.arrowColor,
            onTap: onUndo,
          ),
          _BarButton(
            icon: Icons.restart_alt_rounded,
            label: 'Restart',
            color: theme.textColor,
            onTap: onRestart,
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badgeText;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
            if (badgeText != null)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppConstants.gold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WinOverlay extends ConsumerWidget {
  final int levelId;
  final int stars;
  final ConfettiController confetti;
  final bool daily;

  const _WinOverlay({
    required this.levelId,
    required this.stars,
    required this.confetti,
    this.daily = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider).theme;
    final coins = AppConstants.coinsPerLevel +
        (stars == 3
            ? AppConstants.starBonus3
            : stars == 2
                ? AppConstants.starBonus2
                : 0);

    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 40,
            colors: const [
              AppConstants.gold,
              AppConstants.blue,
              AppConstants.red,
              Colors.white,
            ],
          ),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Level Complete!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration:
                                Duration(milliseconds: 300 + i * 220),
                            curve: Curves.bounceOut,
                            builder: (context, v, child) => Transform.scale(
                              scale: i < stars ? v : 1,
                              child: Opacity(
                                opacity: i < stars ? 1 : 0.25,
                                child: child,
                              ),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              size: 48,
                              color: AppConstants.gold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: AppConstants.gold),
                      const SizedBox(width: 4),
                      Text('+$coins coins',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Time taken, time left, and best time stats
                  Builder(
                    builder: (context) {
                      final game = ref.watch(gameProvider(levelId));
                      final storage = ref.watch(storageProvider);
                      final bestTime = storage.bestTimeForLevel(levelId);
                      final timeTaken = game.timeUsedSeconds ?? 0;
                      final timeLeft = game.timeLeftSeconds ?? 0;

                      String format(int s) =>
                          '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.background.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Time Taken: ',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                Text(format(timeTaken),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                            if (timeLeft > 0)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Time Left: ',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  Text(format(timeLeft),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            if (bestTime != null)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Best Time: ',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  Text(format(bestTime),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppConstants.gold)),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => context.go('/levels'),
                        child: const Text('Levels'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: daily
                            ? () => context.go('/levels')
                            : levelId >= AppConstants.maxLevel
                                ? null
                                : () => context.go('/game/${levelId + 1}'),
                        child: Text(daily ? 'Done' : 'Next Level'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FailOverlay extends ConsumerWidget {
  final int levelId;

  const _FailOverlay({required this.levelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider).theme;
    final notifier = ref.read(gameProvider(levelId).notifier);
    final timerNotifier = ref.read(levelTimerProvider(levelId).notifier);
    final game = ref.watch(gameProvider(levelId));
    final coins = ref.watch(profileProvider).coins;
    final canReviveWithCoins = coins >= AppConstants.reviveCost;
    final canReviveWithAd = game.revivesUsed < AdConfig.maxRevivesPerLevel;
    final isTimeout = game.failReason == 'timeout';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTimeout ? Icons.timer_off_rounded : Icons.heart_broken_rounded,
                  size: 56,
                  color: AppConstants.red,
                ),
                const SizedBox(height: 8),
                Text(
                  isTimeout ? "Time's up!" : 'Out of lives!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 20),
                // Primary Action: Watch ad to continue (restores 2 hearts)
                if (canReviveWithAd)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.gold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () async {
                      final adService = ref.read(adServiceProvider);
                      timerNotifier.pause();
                      final rewarded = await adService.showRewarded(
                        purpose: AdPurpose.revive,
                        context: context,
                      );
                      if (!context.mounted) return;
                      if (rewarded) {
                        notifier.revive(heartsRestored: AdConfig.heartsRestoredOnRevive);
                        if (isTimeout) {
                          timerNotifier.addSeconds(DifficultyConfig.reviveSecondsBonus);
                        } else {
                          timerNotifier.resume();
                        }
                      } else {
                        timerNotifier.resume();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ad not completed. Lives not restored.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded),
                    label: const Text('Watch ad to continue', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                if (canReviveWithAd) const SizedBox(height: 8),
                // Fallback: Coin-based revive
                if (canReviveWithCoins)
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(profileProvider.notifier).spendCoins(AppConstants.reviveCost);
                      if (isTimeout) {
                        timerNotifier.addSeconds(DifficultyConfig.reviveSecondsBonus);
                        notifier.revive();
                      } else {
                        notifier.revive();
                        timerNotifier.resume();
                      }
                    },
                    icon: const Icon(Icons.monetization_on_rounded, color: AppConstants.gold),
                    label: Text('Use ${AppConstants.reviveCost} coins'),
                  ),
                if (canReviveWithCoins) const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    timerNotifier.reset();
                    notifier.restart();
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Retry level'),
                ),
                TextButton(
                  onPressed: () => context.go('/levels'),
                  child: const Text('Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
