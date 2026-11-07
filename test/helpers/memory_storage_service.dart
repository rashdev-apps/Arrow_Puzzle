import 'package:arrow_puzzle/core/storage/storage_service.dart';

/// In-memory [StorageService] for widget tests (async file IO is not
/// available under flutter_tester in some CI/sandbox environments).
class MemoryStorageService implements StorageService {
  final Map<String, dynamic> _settings = {};
  final Map<String, dynamic> _profile = {'coins': 60, 'owned_themes': ['classic', 'dark']};
  final Map<String, dynamic> _progress = {};
  final Map<String, dynamic> _state = {};

  T _get<T>(Map<String, dynamic> box, String key, T fallback) {
    final v = box[key];
    return v is T ? v : fallback;
  }

  @override
  bool get soundOn => _get(_settings, 'sound_on', true);
  @override
  set soundOn(bool v) => _settings['sound_on'] = v;

  @override
  bool get musicOn => _get(_settings, 'music_on', false);
  @override
  set musicOn(bool v) => _settings['music_on'] = v;

  @override
  bool get hapticsOn => _get(_settings, 'haptics_on', true);
  @override
  set hapticsOn(bool v) => _settings['haptics_on'] = v;

  @override
  bool get colorblindMode => _get(_settings, 'colorblind_mode', false);
  @override
  set colorblindMode(bool v) => _settings['colorblind_mode'] = v;

  @override
  bool get relaxedMode => _get(_settings, 'relaxed_mode', false);
  @override
  set relaxedMode(bool v) => _settings['relaxed_mode'] = v;

  @override
  String get themeId => _get(_settings, 'theme_id', 'classic');
  @override
  set themeId(String v) => _settings['theme_id'] = v;

  @override
  bool get onboardingDone => _get(_settings, 'onboarding_done', false);
  @override
  set onboardingDone(bool v) => _settings['onboarding_done'] = v;

  @override
  bool tutorialSeenFor(int levelId) =>
      _get(_settings, 'tutorial_$levelId', false);
  @override
  void markTutorialSeen(int levelId) => _settings['tutorial_$levelId'] = true;

  @override
  int get coins => _get(_profile, 'coins', 60);
  @override
  set coins(int v) => _profile['coins'] = v;

  @override
  int get totalArrowsRemoved => _get(_profile, 'arrows_removed', 0);
  @override
  set totalArrowsRemoved(int v) => _profile['arrows_removed'] = v;

  @override
  int get levelsCompleted => _get(_profile, 'levels_completed', 0);
  @override
  set levelsCompleted(int v) => _profile['levels_completed'] = v;

  @override
  int get bestStreak => _get(_profile, 'best_streak', 0);
  @override
  set bestStreak(int v) => _profile['best_streak'] = v;

  @override
  List<String> get ownedThemes =>
      List<String>.from(_get(_profile, 'owned_themes', ['classic', 'dark']));
  @override
  set ownedThemes(List<String> v) => _profile['owned_themes'] = v;

  @override
  String? get lastDailyDate => _profile['last_daily_date'] as String?;
  @override
  set lastDailyDate(String? v) => _profile['last_daily_date'] = v;

  @override
  int get dailyStreak => _get(_profile, 'daily_streak', 0);
  @override
  set dailyStreak(int v) => _profile['daily_streak'] = v;

  @override
  int starsForDaily(String date) => _get(_profile, 'daily_$date', 0);
  @override
  void setDailyStars(String date, int stars) =>
      _profile['daily_$date'] = stars;

  @override
  int starsForLevel(int levelId) => _get(_progress, 'stars_$levelId', 0);

  @override
  void setLevelStars(int levelId, int stars) {
    if (stars > starsForLevel(levelId)) {
      _progress['stars_$levelId'] = stars;
    }
  }

  @override
  int? bestTimeForLevel(int levelId) => _progress['best_time_$levelId'] as int?;

  @override
  void setBestTimeForLevel(int levelId, int seconds) {
    final cur = bestTimeForLevel(levelId);
    if (cur == null || seconds < cur) {
      _progress['best_time_$levelId'] = seconds;
    }
  }

  @override
  bool isLevelUnlocked(int levelId) =>
      levelId == 1 || starsForLevel(levelId - 1) > 0;

  @override
  Map<String, dynamic>? savedLevelState(int levelId) {
    final raw = _state['level_$levelId'];
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  @override
  void saveLevelState(int levelId, Map<String, dynamic> state) =>
      _state['level_$levelId'] = Map<String, dynamic>.from(state);

  @override
  void clearLevelState(int levelId) => _state.remove('level_$levelId');

  @override
  Future<void> resetProgress() async {
    _profile
      ..clear()
      ..addAll({'coins': 60, 'owned_themes': ['classic', 'dark']});
    _progress.clear();
    _state.clear();
  }
}
