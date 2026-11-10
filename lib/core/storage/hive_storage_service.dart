import 'package:hive_flutter/hive_flutter.dart';

import 'storage_service.dart';

/// Hive-backed [StorageService] used by the app in production.
class HiveStorageService implements StorageService {
  static const String settingsBox = 'settings';
  static const String profileBox = 'profile';
  static const String progressBox = 'progress';
  static const String stateBox = 'state';

  static Future<HiveStorageService> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(settingsBox),
      Hive.openBox<dynamic>(profileBox),
      Hive.openBox<dynamic>(progressBox),
      Hive.openBox<dynamic>(stateBox),
    ]);
    return HiveStorageService._();
  }

  HiveStorageService._();

  Box<dynamic> get _settings => Hive.box(settingsBox);
  Box<dynamic> get _profile => Hive.box(profileBox);
  Box<dynamic> get _progress => Hive.box(progressBox);
  Box<dynamic> get _state => Hive.box(stateBox);

  @override
  bool get soundOn => _settings.get('sound_on', defaultValue: true) as bool;
  @override
  set soundOn(bool v) => _settings.put('sound_on', v);

  @override
  bool get musicOn => _settings.get('music_on', defaultValue: false) as bool;
  @override
  set musicOn(bool v) => _settings.put('music_on', v);

  @override
  bool get hapticsOn => _settings.get('haptics_on', defaultValue: true) as bool;
  @override
  set hapticsOn(bool v) => _settings.put('haptics_on', v);

  @override
  bool get colorblindMode =>
      _settings.get('colorblind_mode', defaultValue: false) as bool;
  @override
  set colorblindMode(bool v) => _settings.put('colorblind_mode', v);

  @override
  bool get relaxedMode =>
      _settings.get('relaxed_mode', defaultValue: false) as bool;
  @override
  set relaxedMode(bool v) => _settings.put('relaxed_mode', v);

  @override
  String get themeId =>
      _settings.get('theme_id', defaultValue: 'classic') as String;
  @override
  set themeId(String v) => _settings.put('theme_id', v);

  @override
  bool get onboardingDone =>
      _settings.get('onboarding_done', defaultValue: false) as bool;
  @override
  set onboardingDone(bool v) => _settings.put('onboarding_done', v);

  @override
  bool tutorialSeenFor(int levelId) =>
      _settings.get('tutorial_$levelId', defaultValue: false) as bool;
  @override
  void markTutorialSeen(int levelId) =>
      _settings.put('tutorial_$levelId', true);

  @override
  int get coins => _profile.get('coins', defaultValue: 60) as int;
  @override
  set coins(int v) => _profile.put('coins', v);

  @override
  int get totalArrowsRemoved =>
      _profile.get('arrows_removed', defaultValue: 0) as int;
  @override
  set totalArrowsRemoved(int v) => _profile.put('arrows_removed', v);

  @override
  int get levelsCompleted =>
      _profile.get('levels_completed', defaultValue: 0) as int;
  @override
  set levelsCompleted(int v) => _profile.put('levels_completed', v);

  @override
  int get bestStreak => _profile.get('best_streak', defaultValue: 0) as int;
  @override
  set bestStreak(int v) => _profile.put('best_streak', v);

  @override
  List<String> get ownedThemes =>
      (_profile.get('owned_themes', defaultValue: <String>['classic', 'dark'])
              as List)
          .cast<String>();
  @override
  set ownedThemes(List<String> v) => _profile.put('owned_themes', v);

  @override
  String? get lastDailyDate => _profile.get('last_daily_date') as String?;
  @override
  set lastDailyDate(String? v) => _profile.put('last_daily_date', v);

  @override
  int get dailyStreak => _profile.get('daily_streak', defaultValue: 0) as int;
  @override
  set dailyStreak(int v) => _profile.put('daily_streak', v);

  @override
  int starsForDaily(String date) =>
      _profile.get('daily_$date', defaultValue: 0) as int;
  @override
  void setDailyStars(String date, int stars) =>
      _profile.put('daily_$date', stars);

  @override
  int starsForLevel(int levelId) =>
      _progress.get('stars_$levelId', defaultValue: 0) as int;

  @override
  void setLevelStars(int levelId, int stars) {
    if (stars > starsForLevel(levelId)) {
      _progress.put('stars_$levelId', stars);
    }
  }

  @override
  int? bestTimeForLevel(int levelId) =>
      _progress.get('best_time_$levelId') as int?;

  @override
  void setBestTimeForLevel(int levelId, int seconds) {
    final current = bestTimeForLevel(levelId);
    if (current == null || seconds < current) {
      _progress.put('best_time_$levelId', seconds);
    }
  }

  @override
  bool isLevelUnlocked(int levelId) {
    if (levelId <= 1) return true;
    return levelId <= maxUnlockedLevel || starsForLevel(levelId - 1) > 0;
  }

  @override
  int get maxUnlockedLevel => _progress.get('max_unlocked', defaultValue: 1) as int;

  @override
  set maxUnlockedLevel(int v) {
    if (v > maxUnlockedLevel) {
      _progress.put('max_unlocked', v);
    }
  }


  @override
  Map<String, dynamic>? savedLevelState(int levelId) {
    final raw = _state.get('level_$levelId');
    if (raw is Map) return raw.cast<String, dynamic>();
    return null;
  }

  @override
  void saveLevelState(int levelId, Map<String, dynamic> state) =>
      _state.put('level_$levelId', state);

  @override
  void clearLevelState(int levelId) => _state.delete('level_$levelId');

  @override
  Future<void> resetProgress() async {
    await Future.wait([_profile.clear(), _progress.clear(), _state.clear()]);
    // Re-seed starting coins and default owned themes.
    coins = 60;
    ownedThemes = ['classic', 'dark'];
  }
}
