/// Persistence contract for all game state. Production uses
/// [HiveStorageService]; tests use an in-memory implementation.
abstract interface class StorageService {
  // ---- Settings -----------------------------------------------------------
  bool get soundOn;
  set soundOn(bool v);

  bool get musicOn;
  set musicOn(bool v);

  bool get hapticsOn;
  set hapticsOn(bool v);

  bool get colorblindMode;
  set colorblindMode(bool v);

  bool get relaxedMode;
  set relaxedMode(bool v);

  String get themeId;
  set themeId(String v);

  bool get onboardingDone;
  set onboardingDone(bool v);

  bool tutorialSeenFor(int levelId);
  void markTutorialSeen(int levelId);

  // ---- Profile ------------------------------------------------------------
  int get coins;
  set coins(int v);

  int get totalArrowsRemoved;
  set totalArrowsRemoved(int v);

  int get levelsCompleted;
  set levelsCompleted(int v);

  int get bestStreak;
  set bestStreak(int v);

  List<String> get ownedThemes;
  set ownedThemes(List<String> v);

  // ---- Daily challenge ----------------------------------------------------
  String? get lastDailyDate;
  set lastDailyDate(String? v);

  int get dailyStreak;
  set dailyStreak(int v);

  int starsForDaily(String date);
  void setDailyStars(String date, int stars);

  // ---- Per-level progress -------------------------------------------------
  int starsForLevel(int levelId);
  void setLevelStars(int levelId, int stars);

  int? bestTimeForLevel(int levelId);
  void setBestTimeForLevel(int levelId, int seconds);

  bool isLevelUnlocked(int levelId);

  // ---- In-progress level state (resume) -----------------------------------
  Map<String, dynamic>? savedLevelState(int levelId);
  void saveLevelState(int levelId, Map<String, dynamic> state);
  void clearLevelState(int levelId);

  Future<void> resetProgress();
}
