import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/core/audio/audio_service.dart';
import 'package:arrow_puzzle/core/haptics/haptics_service.dart';
import 'package:arrow_puzzle/features/game/logic/level_timer_notifier.dart';

class FakeAudioService extends AudioService {
  @override
  Future<void> click() async {}
}

class FakeHapticsService extends HapticsService {
  @override
  void light() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LevelTimerNotifier unit tests', () {
    test('Timer hidden on relaxed mode', () {
      final notifierL3 = LevelTimerNotifier(
        levelId: 3,
        limitSeconds: 100,
        audio: FakeAudioService(),
        haptics: FakeHapticsService(),
        relaxed: false,
      );
      expect(notifierL3.state.isHidden, isFalse);

      final notifierRelaxed = LevelTimerNotifier(
        levelId: 10,
        limitSeconds: 100,
        audio: FakeAudioService(),
        haptics: FakeHapticsService(),
        relaxed: true,
      );
      expect(notifierRelaxed.state.isHidden, isTrue);
    });

    test('Timer starts on start(), pauses and resumes', () {
      final notifier = LevelTimerNotifier(
        levelId: 10,
        limitSeconds: 60,
        audio: FakeAudioService(),
        haptics: FakeHapticsService(),
        relaxed: false,
      );
      expect(notifier.state.isRunning, isFalse);
      expect(notifier.state.hasStarted, isFalse);

      notifier.start();
      expect(notifier.state.isRunning, isTrue);
      expect(notifier.state.hasStarted, isTrue);

      notifier.pause();
      expect(notifier.state.isRunning, isFalse);

      notifier.resume();
      expect(notifier.state.isRunning, isTrue);

      notifier.stopOnWin();
      expect(notifier.state.isRunning, isFalse);
    });

    test('Penalty deducts 3s and alerts', () {
      final notifier = LevelTimerNotifier(
        levelId: 10,
        limitSeconds: 60,
        audio: FakeAudioService(),
        haptics: FakeHapticsService(),
        relaxed: false,
      );
      notifier.start();
      expect(notifier.state.remainingSeconds, 60);

      notifier.applyMistakePenalty();
      expect(notifier.state.remainingSeconds, 57);
      expect(notifier.state.mistakePenaltyAlert, 1);

      notifier.applyMistakePenalty();
      expect(notifier.state.remainingSeconds, 54);
      expect(notifier.state.mistakePenaltyAlert, 2);
    });

    test('Freeze time power-up toggles isFrozen', () {
      final notifier = LevelTimerNotifier(
        levelId: 10,
        limitSeconds: 60,
        audio: FakeAudioService(),
        haptics: FakeHapticsService(),
        relaxed: false,
      );
      notifier.start();
      expect(notifier.state.isFrozen, isFalse);

      notifier.freezeTime(10);
      expect(notifier.state.isFrozen, isTrue);
    });

    test('Revive adds +30s and restarts from timeout', () {
      final notifier = LevelTimerNotifier(
        levelId: 10,
        limitSeconds: 60,
        initialRemainingSeconds: 2,
        audio: FakeAudioService(),
        haptics: FakeHapticsService(),
        relaxed: false,
      );
      notifier.start();

      // Trigger mistake to drop below 0
      notifier.applyMistakePenalty();
      expect(notifier.state.isTimeout, isTrue);
      expect(notifier.state.isRunning, isFalse);

      // Revive +30s
      notifier.addSeconds(30);
      expect(notifier.state.isTimeout, isFalse);
      expect(notifier.state.remainingSeconds, 30);
      expect(notifier.state.isRunning, isTrue);
    });
  });
}
