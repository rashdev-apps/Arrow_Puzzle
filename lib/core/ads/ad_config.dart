import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Configuration for Google Mobile Ads (AdMob) IDs and ad behavior.
/// Uses official Google test IDs by default. Replace production placeholders
/// with real IDs when releasing to app stores.
class AdConfig {
  // ---- Test IDs (Google official) -------------------------------------------
  static const String androidAppIdTest = 'ca-app-pub-3940256099942544~3347511713';
  static const String androidBannerIdTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String androidRewardedIdTest = 'ca-app-pub-3940256099942544/5224354917';

  static const String iosAppIdTest = 'ca-app-pub-3940256099942544~1458002511';
  static const String iosBannerIdTest = 'ca-app-pub-3940256099942544/2934735716';
  static const String iosRewardedIdTest = 'ca-app-pub-3940256099942544/1712485313';

  // ---- Production IDs (PLACEHOLDERS) ---------------------------------------
  // Replace these with your real AdMob unit IDs before shipping to app stores
  static const String androidAppIdProd = 'ca-app-pub-0000000000000000~0000000000';
  static const String androidBannerIdProd = 'ca-app-pub-0000000000000000/0000000000';
  static const String androidRewardedIdProd = 'ca-app-pub-0000000000000000/0000000000';

  static const String iosAppIdProd = 'ca-app-pub-0000000000000000~0000000000';
  static const String iosBannerIdProd = 'ca-app-pub-0000000000000000/0000000000';
  static const String iosRewardedIdProd = 'ca-app-pub-0000000000000000/0000000000';

  /// Toggle test mode: uses test ads in debug or if --dart-define=USE_TEST_ADS=true
  static const bool useTestAds = bool.fromEnvironment('USE_TEST_ADS', defaultValue: true) || kDebugMode;

  static bool get isPlatformSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return useTestAds ? androidBannerIdTest : androidBannerIdProd;
    } else if (Platform.isIOS) {
      return useTestAds ? iosBannerIdTest : iosBannerIdProd;
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return useTestAds ? androidRewardedIdTest : androidRewardedIdProd;
    } else if (Platform.isIOS) {
      return useTestAds ? iosRewardedIdTest : iosRewardedIdProd;
    }
    return '';
  }

  // ---- Game Ad Policy Constants ---------------------------------------------
  static const int freeHintsPerLevel = 2; // First 2 hints are free
  static const int maxHintsPerLevel = 5;  // 2 free + up to 3 rewarded ad hints
  static const int maxRevivesPerLevel = 1;
  static const int heartsRestoredOnRevive = 2;
  static const int tutorialLevelCutoff = 5; // Banners hidden on L1..L5
}

