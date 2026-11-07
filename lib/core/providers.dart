import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/game/logic/game_notifier.dart';
import '../features/game/domain/level.dart';
import '../features/levels/data/level_repository.dart';
import 'ads/ad_service.dart';
import 'ads/iap_service.dart';
import 'audio/audio_service.dart';
import 'haptics/haptics_service.dart';
import 'storage/storage_service.dart';
import 'theme/app_theme.dart';

/// Overridden in main() after Hive initialises.
final storageProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('storageProvider must be overridden'),
);

final audioProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  service.enabled = ref.read(storageProvider).soundOn;
  ref.onDispose(service.dispose);
  return service;
});

final hapticsProvider = Provider<HapticsService>((ref) {
  final service = HapticsService();
  service.enabled = ref.read(storageProvider).hapticsOn;
  return service;
});

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdMobService();
  ref.onDispose(service.dispose);
  return service;
});

final iapServiceProvider = Provider<IapService>((ref) => const StubIapService());

final levelRepositoryProvider =
    Provider<LevelRepository>((ref) => LevelRepository());

// ---- Settings --------------------------------------------------------------

class SettingsState {
  final bool soundOn;
  final bool musicOn;
  final bool hapticsOn;
  final bool colorblindMode;
  final bool relaxedMode;
  final String themeId;

  const SettingsState({
    required this.soundOn,
    required this.musicOn,
    required this.hapticsOn,
    required this.colorblindMode,
    required this.relaxedMode,
    required this.themeId,
  });

  AppThemeData get theme => themeById(themeId);
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final StorageService _storage;

  SettingsNotifier(this._storage)
      : super(SettingsState(
          soundOn: _storage.soundOn,
          musicOn: _storage.musicOn,
          hapticsOn: _storage.hapticsOn,
          colorblindMode: _storage.colorblindMode,
          relaxedMode: _storage.relaxedMode,
          themeId: _storage.themeId,
        ));

  void toggleSound() {
    _storage.soundOn = !_storage.soundOn;
    state = SettingsState(
      soundOn: _storage.soundOn,
      musicOn: state.musicOn,
      hapticsOn: state.hapticsOn,
      colorblindMode: state.colorblindMode,
      relaxedMode: state.relaxedMode,
      themeId: state.themeId,
    );
  }

  void toggleMusic() {
    _storage.musicOn = !_storage.musicOn;
    state = SettingsState(
      soundOn: state.soundOn,
      musicOn: _storage.musicOn,
      hapticsOn: state.hapticsOn,
      colorblindMode: state.colorblindMode,
      relaxedMode: state.relaxedMode,
      themeId: state.themeId,
    );
  }

  void toggleHaptics() {
    _storage.hapticsOn = !_storage.hapticsOn;
    state = SettingsState(
      soundOn: state.soundOn,
      musicOn: state.musicOn,
      hapticsOn: _storage.hapticsOn,
      colorblindMode: state.colorblindMode,
      relaxedMode: state.relaxedMode,
      themeId: state.themeId,
    );
  }

  void toggleColorblind() {
    _storage.colorblindMode = !_storage.colorblindMode;
    state = SettingsState(
      soundOn: state.soundOn,
      musicOn: state.musicOn,
      hapticsOn: state.hapticsOn,
      colorblindMode: _storage.colorblindMode,
      relaxedMode: state.relaxedMode,
      themeId: state.themeId,
    );
  }

  void toggleRelaxedMode() {
    _storage.relaxedMode = !_storage.relaxedMode;
    state = SettingsState(
      soundOn: state.soundOn,
      musicOn: state.musicOn,
      hapticsOn: state.hapticsOn,
      colorblindMode: state.colorblindMode,
      relaxedMode: _storage.relaxedMode,
      themeId: state.themeId,
    );
  }

  void setTheme(String themeId) {
    _storage.themeId = themeId;
    state = SettingsState(
      soundOn: state.soundOn,
      musicOn: state.musicOn,
      hapticsOn: state.hapticsOn,
      colorblindMode: state.colorblindMode,
      relaxedMode: state.relaxedMode,
      themeId: themeId,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref.watch(storageProvider));
});

// ---- Profile (coins, stats, themes) ----------------------------------------

class ProfileState {
  final int coins;
  final int totalArrowsRemoved;
  final int levelsCompleted;
  final int bestStreak;
  final int dailyStreak;
  final List<String> ownedThemes;

  const ProfileState({
    required this.coins,
    required this.totalArrowsRemoved,
    required this.levelsCompleted,
    required this.bestStreak,
    required this.dailyStreak,
    required this.ownedThemes,
  });
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final StorageService _storage;

  ProfileNotifier(this._storage)
      : super(ProfileState(
          coins: _storage.coins,
          totalArrowsRemoved: _storage.totalArrowsRemoved,
          levelsCompleted: _storage.levelsCompleted,
          bestStreak: _storage.bestStreak,
          dailyStreak: _storage.dailyStreak,
          ownedThemes: _storage.ownedThemes,
        ));

  void refresh() => state = ProfileState(
        coins: _storage.coins,
        totalArrowsRemoved: _storage.totalArrowsRemoved,
        levelsCompleted: _storage.levelsCompleted,
        bestStreak: _storage.bestStreak,
        dailyStreak: _storage.dailyStreak,
        ownedThemes: _storage.ownedThemes,
      );

  bool spendCoins(int amount) {
    if (_storage.coins < amount) return false;
    _storage.coins = _storage.coins - amount;
    refresh();
    return true;
  }

  void addCoins(int amount) {
    _storage.coins = _storage.coins + amount;
    refresh();
  }

  bool unlockTheme(String themeId, int cost) {
    if (_storage.ownedThemes.contains(themeId)) return true;
    if (!spendCoins(cost)) return false;
    _storage.ownedThemes = [..._storage.ownedThemes, themeId];
    refresh();
    return true;
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.watch(storageProvider));
});

// ---- Levels ----------------------------------------------------------------

final levelProvider = FutureProvider.autoDispose
    .family<Level, int>((ref, levelId) async {
  return ref.watch(levelRepositoryProvider).load(levelId);
});

final dailyLevelProvider = FutureProvider<Level>((ref) async {
  return ref.watch(levelRepositoryProvider).loadDaily(DateTime.now());
});

final gameProvider = StateNotifierProvider.autoDispose
    .family<GameNotifier, GameState, int>((ref, levelId) {
  // If levelId matches dailyKey format (YYYYMMDD), resolve through dailyLevelProvider
  final Level? level;
  if (levelId > 20000000) {
    level = ref.watch(dailyLevelProvider).value;
  } else {
    level = ref.watch(levelProvider(levelId)).value;
  }

  if (level == null) {
    // Placeholder until the level loads; the screen shows a spinner and the
    // provider rebuilds once the level resolves.
    throw UnimplementedError('level not loaded');
  }
  final storage = ref.watch(storageProvider);
  final hasSave = storage.savedLevelState(levelId) != null;
  return GameNotifier(level: level, storage: storage, resume: hasSave);
});
