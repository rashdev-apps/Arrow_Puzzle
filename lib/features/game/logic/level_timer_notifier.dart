import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/haptics/haptics_service.dart';
import '../../../core/providers.dart';
import '../logic/difficulty_config.dart';

class TimerState {
  final int totalLimitSeconds;
  final int remainingSeconds;
  final int elapsedMilliseconds;
  final bool isRunning;
  final bool hasStarted;
  final bool isFrozen;
  final bool isTimeout;
  final bool isHidden; // hidden on levels 1..5 or relaxed mode
  final int mistakePenaltyAlert; // incremented to trigger floating -3s

  const TimerState({
    required this.totalLimitSeconds,
    required this.remainingSeconds,
    required this.elapsedMilliseconds,
    required this.isRunning,
    required this.hasStarted,
    required this.isFrozen,
    required this.isTimeout,
    required this.isHidden,
    this.mistakePenaltyAlert = 0,
  });

  TimerState copyWith({
    int? totalLimitSeconds,
    int? remainingSeconds,
    int? elapsedMilliseconds,
    bool? isRunning,
    bool? hasStarted,
    bool? isFrozen,
    bool? isTimeout,
    bool? isHidden,
    int? mistakePenaltyAlert,
  }) {
    return TimerState(
      totalLimitSeconds: totalLimitSeconds ?? this.totalLimitSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      elapsedMilliseconds: elapsedMilliseconds ?? this.elapsedMilliseconds,
      isRunning: isRunning ?? this.isRunning,
      hasStarted: hasStarted ?? this.hasStarted,
      isFrozen: isFrozen ?? this.isFrozen,
      isTimeout: isTimeout ?? this.isTimeout,
      isHidden: isHidden ?? this.isHidden,
      mistakePenaltyAlert: mistakePenaltyAlert ?? this.mistakePenaltyAlert,
    );
  }

  double get fractionRemaining =>
      totalLimitSeconds > 0 ? (remainingSeconds / totalLimitSeconds).clamp(0.0, 1.0) : 1.0;
  bool get isWarning => fractionRemaining <= 0.30;
  bool get isCritical => fractionRemaining <= 0.15;

  int get elapsedSeconds => totalLimitSeconds > 0
      ? (totalLimitSeconds - remainingSeconds).clamp(0, totalLimitSeconds)
      : (elapsedMilliseconds / 1000).floor();

  bool get isTimeUp => isTimeout || (totalLimitSeconds > 0 && remainingSeconds <= 0);
}

class LevelTimerNotifier extends StateNotifier<TimerState> {
  final int levelId;
  final int limitSeconds;
  final AudioService _audio;
  final HapticsService _haptics;
  final bool _relaxed;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  int _lastTickAudioSecond = -1;
  int _freezeRemainingMs = 0;

  LevelTimerNotifier({
    required this.levelId,
    required this.limitSeconds,
    required AudioService audio,
    required HapticsService haptics,
    required bool relaxed,
    int? initialRemainingSeconds,
    bool initialHasStarted = false,
  })  : _audio = audio,
        _haptics = haptics,
        _relaxed = relaxed,
        super(TimerState(
          totalLimitSeconds: limitSeconds,
          remainingSeconds: initialRemainingSeconds ?? limitSeconds,
          elapsedMilliseconds: 0,
          isRunning: false,
          hasStarted: initialHasStarted,
          isFrozen: false,
          isTimeout: false,
          isHidden: relaxed,
        )) {
    // If resuming an already started game, we don't auto-run until first tap or explicit start
  }

  /// Start running on first player interaction.
  void start() {
    if (state.isHidden || state.isTimeout) return;
    if (state.isRunning) return;

    state = state.copyWith(isRunning: true, hasStarted: true);
    _startTicker();
  }

  void pause() {
    if (!state.isRunning) return;
    _stopTicker();
    state = state.copyWith(isRunning: false);
  }

  void resume() {
    if (state.isHidden || state.isTimeout || !state.hasStarted) return;
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);
    _startTicker();
  }

  /// Penalty for blocked taps (-3s).
  void applyMistakePenalty() {
    if (state.isHidden || state.isTimeout) return;
    final newRemaining = (state.remainingSeconds - DifficultyConfig.mistakePenaltySeconds).clamp(0, state.totalLimitSeconds);
    final timeout = newRemaining <= 0;
    state = state.copyWith(
      remainingSeconds: newRemaining,
      isTimeout: timeout,
      isRunning: timeout ? false : state.isRunning,
      mistakePenaltyAlert: state.mistakePenaltyAlert + 1,
    );
    if (timeout) {
      _stopTicker();
    }
  }

  /// Freeze power-up: freezes time progression for 10 seconds.
  void freezeTime(int seconds) {
    if (state.isHidden || state.isTimeout) return;
    _freezeRemainingMs += seconds * 1000;
    state = state.copyWith(isFrozen: true);
  }

  /// Revive / add +30s when revived or time extended.
  void addSeconds(int seconds) {
    final newRemaining = (state.remainingSeconds + seconds).clamp(1, state.totalLimitSeconds + seconds);
    state = state.copyWith(
      remainingSeconds: newRemaining,
      isTimeout: false,
      isRunning: true,
    );
    _startTicker();
  }

  void reset() {
    _stopTicker();
    _lastTickAudioSecond = -1;
    _freezeRemainingMs = 0;
    state = TimerState(
      totalLimitSeconds: limitSeconds,
      remainingSeconds: limitSeconds,
      elapsedMilliseconds: 0,
      isRunning: false,
      hasStarted: false,
      isFrozen: false,
      isTimeout: false,
      isHidden: _relaxed,
    );
  }

  void stopOnWin() {
    _stopTicker();
    state = state.copyWith(isRunning: false);
  }

  void _startTicker() {
    _ticker?.dispose();
    _lastElapsed = Duration.zero;
    _ticker = Ticker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    final deltaMs = delta.inMilliseconds;
    if (deltaMs <= 0) return;

    if (_freezeRemainingMs > 0) {
      _freezeRemainingMs -= deltaMs;
      if (_freezeRemainingMs <= 0) {
        _freezeRemainingMs = 0;
        state = state.copyWith(isFrozen: false);
      }
      return;
    }

    final newElapsedMs = state.elapsedMilliseconds + deltaMs;
    // Compute remaining seconds accurately
    final consumedSeconds = (newElapsedMs / 1000).floor();
    final newRemainingSeconds = (state.totalLimitSeconds - consumedSeconds).clamp(0, state.totalLimitSeconds);

    if (newRemainingSeconds != state.remainingSeconds) {
      // Check audio tick & haptics for last 10s
      if (newRemainingSeconds <= 10 && newRemainingSeconds > 0 && newRemainingSeconds != _lastTickAudioSecond) {
        _lastTickAudioSecond = newRemainingSeconds;
        _audio.click();
        if (newRemainingSeconds == 10) {
          _haptics.light();
        }
      }

      if (newRemainingSeconds <= 0) {
        _stopTicker();
        state = state.copyWith(
          remainingSeconds: 0,
          elapsedMilliseconds: newElapsedMs,
          isRunning: false,
          isTimeout: true,
        );
        return;
      }
    }

    state = state.copyWith(
      remainingSeconds: newRemainingSeconds,
      elapsedMilliseconds: newElapsedMs,
    );
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

final levelTimerProvider = StateNotifierProvider.autoDispose.family<LevelTimerNotifier, TimerState, int>((ref, levelId) {
  final audio = ref.watch(audioProvider);
  final haptics = ref.watch(hapticsProvider);
  final settings = ref.watch(settingsProvider);
  final storage = ref.watch(storageProvider);

  // Retrieve level limit
  int limit;
  if (levelId > 20000000) {
    final daily = ref.watch(dailyLevelProvider).value;
    limit = daily?.effectiveTimeLimitSeconds ?? 180;
  } else {
    final level = ref.watch(levelProvider(levelId)).value;
    limit = level?.effectiveTimeLimitSeconds ?? 120;
  }

  // Check saved state for resume
  final saved = storage.savedLevelState(levelId);
  final savedRemaining = saved?['timer_remaining'] as int?;
  final savedStarted = saved?['timer_started'] as bool? ?? false;

  return LevelTimerNotifier(
    levelId: levelId,
    limitSeconds: limit,
    audio: audio,
    haptics: haptics,
    relaxed: settings.relaxedMode,
    initialRemainingSeconds: savedRemaining,
    initialHasStarted: savedStarted,
  );
});

