import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/storage/storage_service.dart';
import '../domain/arrow.dart';
import '../domain/grid_cell.dart';
import '../domain/level.dart';
import 'difficulty_config.dart';
import 'move_validator.dart';

enum GameStatus { playing, won, failed }

class GameState {
  final Level level;
  final Set<String> remaining;
  final int hearts;
  final int mistakes;
  final int undoCharges;
  final List<String> undoStack;
  final GameStatus status;
  final String? failReason; // 'hearts' or 'timeout'
  final int? timeUsedSeconds;
  final int? timeLeftSeconds;
  final int? customStars;
  final int hintsUsed;
  final int revivesUsed;

  /// Arrow currently highlighted by the hint button, if any.
  final String? hintArrowId;

  /// Arrow that was just tapped while blocked (drives red shake animation).
  final String? blockedArrowId;
  final List<GridCell> blockedRay;

  /// True while a slide-out animation is running (taps ignored).
  final bool slideInProgress;

  const GameState({
    required this.level,
    required this.remaining,
    required this.hearts,
    required this.mistakes,
    required this.undoCharges,
    required this.undoStack,
    required this.status,
    this.hintArrowId,
    this.blockedArrowId,
    this.blockedRay = const [],
    this.slideInProgress = false,
    this.failReason,
    this.timeUsedSeconds,
    this.timeLeftSeconds,
    this.customStars,
    this.hintsUsed = 0,
    this.revivesUsed = 0,
  });

  GameState copyWith({
    Set<String>? remaining,
    int? hearts,
    int? mistakes,
    int? undoCharges,
    List<String>? undoStack,
    GameStatus? status,
    String? Function()? hintArrowId,
    String? Function()? blockedArrowId,
    List<GridCell>? blockedRay,
    bool? slideInProgress,
    String? failReason,
    int? timeUsedSeconds,
    int? timeLeftSeconds,
    int? customStars,
    int? hintsUsed,
    int? revivesUsed,
  }) {
    return GameState(
      level: level,
      remaining: remaining ?? this.remaining,
      hearts: hearts ?? this.hearts,
      mistakes: mistakes ?? this.mistakes,
      undoCharges: undoCharges ?? this.undoCharges,
      undoStack: undoStack ?? this.undoStack,
      status: status ?? this.status,
      hintArrowId: hintArrowId != null ? hintArrowId() : this.hintArrowId,
      blockedArrowId:
          blockedArrowId != null ? blockedArrowId() : this.blockedArrowId,
      blockedRay: blockedRay ?? this.blockedRay,
      slideInProgress: slideInProgress ?? this.slideInProgress,
      failReason: failReason ?? this.failReason,
      timeUsedSeconds: timeUsedSeconds ?? this.timeUsedSeconds,
      timeLeftSeconds: timeLeftSeconds ?? this.timeLeftSeconds,
      customStars: customStars ?? this.customStars,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      revivesUsed: revivesUsed ?? this.revivesUsed,
    );
  }

  /// Evaluated stars (or customStars computed with time limit & relaxed rules)
  int get starsEarned => customStars ?? (mistakes == 0 ? 3 : (mistakes <= 1 ? 2 : 1));

  List<Arrow> get remainingArrows => level.board.arrows
      .where((a) => remaining.contains(a.id))
      .toList(growable: false);
}

/// Result of a tap, handed back to the UI so it can drive animations.
sealed class TapOutcome {}

class TapIgnored extends TapOutcome {}

class TapValid extends TapOutcome {
  final Arrow arrow;
  TapValid(this.arrow);
}

class TapBlocked extends TapOutcome {
  final Arrow arrow;
  final List<Arrow> blockers;
  final List<GridCell> blockedRay;
  TapBlocked(this.arrow, this.blockers, this.blockedRay);
}

class GameNotifier extends StateNotifier<GameState> {
  final StorageService _storage;
  final MoveValidator _validator = const MoveValidator();

  GameNotifier({
    required Level level,
    required StorageService storage,
    bool resume = false,
  })  : _storage = storage,
        super(_initialState(level, storage, resume));

  static GameState _initialState(
      Level level, StorageService storage, bool resume) {
    final saved = resume ? storage.savedLevelState(level.id) : null;
    if (saved != null) {
      final remaining = (saved['remaining'] as List).cast<String>().toSet();
      if (remaining.isNotEmpty) {
        return GameState(
          level: level,
          remaining: remaining,
          hearts: saved['hearts'] as int? ?? AppConstants.heartsPerLevel,
          mistakes: saved['mistakes'] as int? ?? 0,
          undoCharges:
              saved['undo_charges'] as int? ?? AppConstants.undoChargesPerLevel,
          undoStack: (saved['undo_stack'] as List? ?? const []).cast<String>(),
          status: GameStatus.playing,
        );
      }
    }
    return GameState(
      level: level,
      remaining: level.board.arrows.map((a) => a.id).toSet(),
      hearts: AppConstants.heartsPerLevel,
      mistakes: 0,
      undoCharges: AppConstants.undoChargesPerLevel,
      undoStack: const [],
      status: GameStatus.playing,
    );
  }

  /// Validate a tap. When valid, the UI plays the slide and then calls
  /// [completeSlide]; when blocked the UI shakes and calls [registerMistake].
  TapOutcome evaluateTap(Arrow arrow) {
    if (state.status != GameStatus.playing || state.slideInProgress) {
      return TapIgnored();
    }
    final result =
        _validator.evaluate(state.level.board, arrow, state.remaining);
    if (result.valid) return TapValid(arrow);
    return TapBlocked(arrow, result.blockers, result.blockedRay);
  }

  void beginSlide(Arrow arrow) {
    state = state.copyWith(slideInProgress: true, hintArrowId: () => null);
  }

  /// Called when the slide-out animation finishes: actually remove the arrow.
  void completeSlide(Arrow arrow) {
    if (!state.remaining.contains(arrow.id)) return;
    final remaining = {...state.remaining}..remove(arrow.id);
    final undoStack = [...state.undoStack, arrow.id];
    final won = remaining.isEmpty;
    state = state.copyWith(
      remaining: remaining,
      undoStack: undoStack,
      slideInProgress: false,
      status: won ? GameStatus.won : state.status,
    );
    _storage.totalArrowsRemoved = _storage.totalArrowsRemoved + 1;
    if (won) {
      _onWin();
    } else {
      _persist();
    }
  }

  /// A blocked tap: lose a heart, flash red.
  void registerMistake(Arrow arrow, List<GridCell> blockedRay) {
    if (state.status != GameStatus.playing) return;
    final hearts = state.hearts - 1;
    state = state.copyWith(
      hearts: hearts,
      mistakes: state.mistakes + 1,
      blockedArrowId: () => arrow.id,
      blockedRay: blockedRay,
      status: hearts <= 0 ? GameStatus.failed : state.status,
      failReason: hearts <= 0 ? 'hearts' : null,
    );
    _persist();
  }

  /// Called when the shake animation ends.
  void clearBlocked() {
    state = state.copyWith(blockedArrowId: () => null, blockedRay: const []);
  }

  /// Highlight a currently-free arrow.
  String? useHint() {
    if (state.status != GameStatus.playing) return null;
    final free = state.level.board.freeArrows(state.remaining);
    if (free.isEmpty) return null;
    free.shuffle();
    final pick = free.first;
    state = state.copyWith(
      hintArrowId: () => pick.id,
      hintsUsed: state.hintsUsed + 1,
    );
    return pick.id;
  }

  void clearHint() => state = state.copyWith(hintArrowId: () => null);

  /// Restore the most recently removed arrow (animated reverse by the UI).
  Arrow? undo() {
    if (state.status != GameStatus.playing || state.slideInProgress) return null;
    if (state.undoStack.isEmpty) return null;
    if (state.undoCharges <= 0 && _storage.coins < AppConstants.undoCost) {
      return null;
    }
    if (state.undoCharges > 0) {
      state = state.copyWith(undoCharges: state.undoCharges - 1);
    } else {
      _storage.coins = _storage.coins - AppConstants.undoCost;
    }
    final undoStack = [...state.undoStack]..removeLast();
    final restoredId = state.undoStack.last;
    state = state.copyWith(
      remaining: {...state.remaining, restoredId},
      undoStack: undoStack,
    );
    _persist();
    return state.level.board.arrowById(restoredId);
  }

  void restart() {
    _storage.clearLevelState(state.level.id);
    state = GameState(
      level: state.level,
      remaining: state.level.board.arrows.map((a) => a.id).toSet(),
      hearts: AppConstants.heartsPerLevel,
      mistakes: 0,
      undoCharges: AppConstants.undoChargesPerLevel,
      undoStack: const [],
      status: GameStatus.playing,
    );
  }

  /// Called when level is completed to record timer stats and compute stars.
  void finalizeWin({
    required int timeLeftSeconds,
    required int limitSeconds,
    required bool relaxedMode,
  }) {
    final timeUsed = (limitSeconds - timeLeftSeconds).clamp(0, limitSeconds);
    final stars = DifficultyConfig.computeStars(
      mistakes: state.mistakes,
      timeLeftSeconds: timeLeftSeconds,
      limitSeconds: limitSeconds,
      relaxedMode: relaxedMode,
    );

    state = state.copyWith(
      timeUsedSeconds: timeUsed,
      timeLeftSeconds: timeLeftSeconds,
      customStars: stars,
      status: GameStatus.won,
    );

    final storage = _storage;
    storage.clearLevelState(state.level.id);
    storage.setLevelStars(state.level.id, stars);
    if (!relaxedMode) {
      storage.setBestTimeForLevel(state.level.id, timeUsed);
    }
    if (storage.starsForLevel(state.level.id) > 0 &&
        storage.levelsCompleted < state.level.id) {
      storage.levelsCompleted = state.level.id;
    }
    // Coins: base reward + star bonus (+ extra fast completion bonus for daily/levels)
    final bonus = stars == 3
        ? AppConstants.starBonus3
        : stars == 2
            ? AppConstants.starBonus2
            : 0;
    final fastBonus = (timeLeftSeconds >= limitSeconds * 0.5) ? 10 : 0;
    storage.coins = storage.coins + AppConstants.coinsPerLevel + bonus + fastBonus;
  }

  /// Timeout failure triggered by the countdown timer.
  void handleTimeout() {
    if (state.status != GameStatus.playing) return;
    state = state.copyWith(
      status: GameStatus.failed,
      failReason: 'timeout',
    );
    _persist();
  }

  /// Revive after failing: restore hearts (e.g. 2 hearts from AdConfig) and keep playing.
  void revive({int heartsRestored = 2}) {
    if (state.status != GameStatus.failed) return;
    state = state.copyWith(
      hearts: heartsRestored,
      status: GameStatus.playing,
      failReason: null,
      revivesUsed: state.revivesUsed + 1,
    );
    _persist();
  }

  void _onWin() {
    final storage = _storage;
    storage.clearLevelState(state.level.id);
    storage.setLevelStars(state.level.id, state.starsEarned);
    if (storage.starsForLevel(state.level.id) > 0 &&
        storage.levelsCompleted < state.level.id) {
      storage.levelsCompleted = state.level.id;
    }
    // Coins: base reward + star bonus.
    final bonus = state.starsEarned == 3
        ? AppConstants.starBonus3
        : state.starsEarned == 2
            ? AppConstants.starBonus2
            : 0;
    storage.coins = storage.coins + AppConstants.coinsPerLevel + bonus;
  }

  void _persist() {
    _storage.saveLevelState(state.level.id, {
      'remaining': state.remaining.toList(),
      'hearts': state.hearts,
      'mistakes': state.mistakes,
      'undo_charges': state.undoCharges,
      'undo_stack': state.undoStack,
    });
  }
}
