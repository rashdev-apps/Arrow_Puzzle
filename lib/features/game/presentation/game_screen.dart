import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_config.dart';
import '../../../core/ads/ad_service.dart';
import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/ui_components.dart';
import '../../levels/data/level_repository.dart';
import '../domain/level.dart';
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
    if (_gameId == 0) return;
    final timerNotifier = ref.read(levelTimerProvider(_gameId).notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      timerNotifier.pause();
    } else if (state == AppLifecycleState.resumed) {
      final game = ref.read(gameProvider(_gameId));
      if (game.status == GameStatus.inProgress && game.movesTaken > 0) {
        timerNotifier.resume();
      }
    }
  }

  void _onFirstInteraction() {
    if (_gameId == 0) return;
    ref.read(levelTimerProvider(_gameId).notifier).start();
  }

  void _onWin(GameState game) {
    if (_winHandled) return;
    _winHandled = true;

    final storage = ref.read(storageProvider);
    final profileNotifier = ref.read(profileProvider.notifier);
    final timerState = ref.read(levelTimerProvider(_gameId));

    final coinsEarned = AppConstants.coinsPerLevel +
        (game.starsEarned == 3
            ? AppConstants.starBonus3
            : game.starsEarned == 2
                ? AppConstants.starBonus2
                : 0);

    profileNotifier.addCoins(coinsEarned);
    profileNotifier.recordLevelCompleted(game.starsEarned);

    if (widget.daily) {
      final todayStr = LevelRepository.dailyKeyString(DateTime.now());
      storage.setDailyStars(todayStr, game.starsEarned);
      storage.dailyStreak += 1;
      storage.lastDailyDate = todayStr;
    } else {
      storage.setLevelStars(_gameId, game.starsEarned);
      if (timerState.elapsedSeconds > 0) {
        storage.setBestTimeForLevel(_gameId, timerState.elapsedSeconds);
      }
      if (_gameId >= storage.maxUnlockedLevel) {
        storage.maxUnlockedLevel = _gameId + 1;
      }
      storage.clearLevelState(_gameId);
    }
  }

  Future<void> _onHint() async {
    final notifier = ref.read(gameProvider(_gameId).notifier);
    final timerNotifier = ref.read(levelTimerProvider(_gameId).notifier);
    final audio = ref.read(audioProvider);
    final adService = ref.read(adServiceProvider);

    final game = ref.read(gameProvider(_gameId));
    final hintsUsed = game.hintsUsed;

    if (hintsUsed >= AdConfig.maxHintsPerLevel) {
      _showSnack('Max hints used for this level (${AdConfig.maxHintsPerLevel})');
      return;
    }

    timerNotifier.pause();
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
      loading: () => const Scaffold(
        backgroundColor: DesignTokens.creamBg,
        body: Center(
          child: CircularProgressIndicator(color: DesignTokens.brownPrimary),
        ),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: DesignTokens.creamBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load level', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Retry',
                onPressed: () => ref.invalidate(levelProvider(widget.levelId)),
              ),
            ],
          ),
        ),
      ),
      data: (level) {
        final gameId = widget.daily ? LevelRepository.dailyKey(DateTime.now()) : level.id;
        _gameId = gameId;

        final timerState = ref.watch(levelTimerProvider(gameId));
        if (timerState.isTimeUp && !_winHandled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(gameProvider(gameId).notifier).failByTimeout();
          });
        }

        ref.listen<GameState>(gameProvider(gameId), (prev, next) {
          if (next.status == GameStatus.won && prev?.status != GameStatus.won) {
            final timerNotifier = ref.read(levelTimerProvider(gameId).notifier);
            timerNotifier.pause();

            final relaxed = ref.read(settingsProvider).relaxedMode;
            ref.read(gameProvider(gameId).notifier).computeStars(
                  elapsedSeconds: timerState.elapsedSeconds,
                  limitSeconds: timerState.totalLimitSeconds,
                  relaxedMode: relaxed,
                );

            ref.read(audioProvider).win();
            ref.read(hapticsProvider).medium();
            _confetti.play();
            _onWin(ref.read(gameProvider(gameId)));
          }
          if (next.status == GameStatus.failed && prev?.status != GameStatus.failed) {
            ref.read(levelTimerProvider(gameId).notifier).pause();
            ref.read(audioProvider).heartLost();
            ref.read(hapticsProvider).error();
          }
        });

        final game = ref.watch(gameProvider(gameId));

        return Scaffold(
          backgroundColor: DesignTokens.creamBg,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _TopBar(level: level, daily: widget.daily),
                    const SizedBox(height: 6),
                    // Centered countdown timer pill (null on first 3 levels)
                    if (level.id > 3)
                      Center(
                        child: LevelTimerPill(levelId: gameId),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      hintsUsed: game.hintsUsed,
                    ),
                  ],
                ),
                if (game.status == GameStatus.won)
                  _WinOverlay(
                    level: level,
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
}

class _TopBar extends ConsumerWidget {
  final Level level;
  final bool daily;

  const _TopBar({
    required this.level,
    this.daily = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider(level.id));
    final profile = ref.watch(profileProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.brownPrimary),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    daily ? 'Daily Challenge' : 'Level ${level.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: DesignTokens.brownDark,
                    ),
                  ),
                  if (!daily) DifficultyChip(level: level.id),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Hearts
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
                        size: 22,
                        color: i < game.hearts
                            ? DesignTokens.errorRed
                            : DesignTokens.brownMuted.withAlpha(80),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              StatChip(
                icon: Icons.monetization_on_rounded,
                iconColor: DesignTokens.accentGold,
                text: '${profile.coins}',
                onTap: () => context.push('/shop'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  final VoidCallback onHint;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final int hintsUsed;

  const _BottomBar({
    required this.onHint,
    required this.onUndo,
    required this.onRestart,
    required this.hintsUsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalLeft = (AdConfig.maxHintsPerLevel - hintsUsed).clamp(0, AdConfig.maxHintsPerLevel);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.lightbulb_rounded,
            label: 'Hint ($totalLeft left)',
            badge: 'AD',
            color: DesignTokens.hintBlue,
            onTap: totalLeft > 0 ? onHint : () {},
          ),
          _ActionButton(
            icon: Icons.undo_rounded,
            label: 'Undo',
            color: DesignTokens.brownPrimary,
            onTap: onUndo,
          ),
          _ActionButton(
            icon: Icons.restart_alt_rounded,
            label: 'Restart',
            color: DesignTokens.brownDark,
            onTap: onRestart,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: DesignTokens.creamSurface,
          borderRadius: DesignTokens.br16,
          boxShadow: DesignTokens.shadowSoft,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: DesignTokens.accentAmber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WinOverlay extends ConsumerWidget {
  final Level level;
  final int stars;
  final ConfettiController confetti;
  final bool daily;

  const _WinOverlay({
    required this.level,
    required this.stars,
    required this.confetti,
    this.daily = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(levelTimerProvider(level.id));
    final coinsEarned = AppConstants.coinsPerLevel +
        (stars == 3 ? AppConstants.starBonus3 : (stars == 2 ? AppConstants.starBonus2 : 0));

    return Container(
      color: Colors.black.withAlpha(120),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ConfettiWidget(
            confettiController: confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 35,
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(DesignTokens.s24),
              decoration: BoxDecoration(
                color: DesignTokens.creamSurface,
                borderRadius: DesignTokens.br24,
                boxShadow: DesignTokens.shadowElevated,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    daily ? 'Daily Solved!' : 'Level ${level.id} Clear!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: DesignTokens.brownDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Animated Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final active = i < stars;
                      return Icon(
                        active ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 42,
                        color: active ? DesignTokens.accentAmber : DesignTokens.brownMuted,
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: DesignTokens.accentGold, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        '+$coinsEarned Coins',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.brownDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Time: ${timerState.elapsedSeconds}s',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.brownMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    width: double.infinity,
                    label: daily ? 'Home' : 'Next Level',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      if (daily) {
                        context.go('/home');
                      } else {
                        context.go('/game/${level.id + 1}');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    width: double.infinity,
                    label: 'Level Map',
                    icon: Icons.map_rounded,
                    onPressed: () => context.go('/levels'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailOverlay extends ConsumerWidget {
  final int levelId;

  const _FailOverlay({required this.levelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameProvider(levelId).notifier);
    final timerNotifier = ref.read(levelTimerProvider(levelId).notifier);
    final game = ref.watch(gameProvider(levelId));
    final canReviveWithAd = game.revivesUsed < AdConfig.maxRevivesPerLevel;
    final isTimeout = game.failReason == 'timeout';

    return Container(
      color: Colors.black.withAlpha(140),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(DesignTokens.s24),
        decoration: BoxDecoration(
          color: DesignTokens.creamSurface,
          borderRadius: DesignTokens.br24,
          boxShadow: DesignTokens.shadowElevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTimeout ? Icons.timer_off_rounded : Icons.heart_broken_rounded,
              color: DesignTokens.errorRed,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              isTimeout ? "Time's Up!" : 'Out of Lives!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: DesignTokens.brownDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTimeout
                  ? 'Ran out of time on this puzzle.'
                  : 'Too many blocked collisions.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DesignTokens.brownMuted,
              ),
            ),
            const SizedBox(height: 24),
            if (canReviveWithAd)
              PrimaryButton(
                width: double.infinity,
                backgroundColor: DesignTokens.accentAmber,
                label: 'Watch Ad to Revive',
                icon: Icons.play_circle_fill_rounded,
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
                    timerNotifier.resume();
                  } else {
                    timerNotifier.resume();
                  }
                },
              ),
            if (canReviveWithAd) const SizedBox(height: 12),
            SecondaryButton(
              width: double.infinity,
              label: 'Retry Level',
              icon: Icons.restart_alt_rounded,
              onPressed: () {
                timerNotifier.reset();
                notifier.restart();
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text(
                'Back to Home',
                style: TextStyle(
                  color: DesignTokens.brownMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
