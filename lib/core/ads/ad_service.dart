import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';
import 'local_ad_simulator_dialog.dart';

enum AdPurpose {
  revive,
  hint,
}

abstract class AdService {
  Future<void> initialize();
  Future<void> requestConsent();
  Future<bool> showRewarded({required AdPurpose purpose, BuildContext? context});
  bool get isRewardedReady;
  ValueListenable<bool> get rewardedReadyListenable;
  Widget buildBannerWidget({Key? key});
  void dispose();
}

/// Production AdMob integration using google_mobile_ads & Google UMP consent.
class AdMobService implements AdService {
  RewardedAd? _rewardedAd;
  bool _isRewardedReady = false;
  final ValueNotifier<bool> _rewardedNotifier = ValueNotifier<bool>(false);
  int _retryAttempt = 0;
  bool _isShowingAd = false;
  bool _isInitialized = false;

  @override
  bool get isRewardedReady => _isRewardedReady;

  @override
  ValueListenable<bool> get rewardedReadyListenable => _rewardedNotifier;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      _logAnalytics('ad_service_initialized');
      await requestConsent();
      loadRewarded();
    } catch (e) {
      debugPrint('[AdMobService] Initialization error: $e');
    }
  }

  @override
  Future<void> requestConsent() async {
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint('[AdMobService] Consent form error: ${formError.message}');
          }
        });
      },
      (formError) {
        debugPrint('[AdMobService] Consent info error: ${formError.message}');
      },
    );
  }

  void loadRewarded() {
    final adUnitId = AdConfig.rewardedAdUnitId;
    if (adUnitId.isEmpty) return;

    _logAnalytics('ad_requested', {'unit': 'rewarded'});

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedReady = true;
          _rewardedNotifier.value = true;
          _retryAttempt = 0;
          _logAnalytics('ad_loaded', {'unit': 'rewarded'});
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedReady = false;
          _rewardedNotifier.value = false;
          _logAnalytics('ad_failed', {'unit': 'rewarded', 'error': error.message});

          // Exponential backoff, max 3 retries
          if (_retryAttempt < 3) {
            _retryAttempt++;
            final delay = Duration(seconds: 1 << _retryAttempt);
            Timer(delay, loadRewarded);
          }
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded({required AdPurpose purpose, BuildContext? context}) async {
    // If running in local web/desktop or on device before AdMob test ads fill,
    // show the interactive Local Ad Simulator so developers and testers can verify
    // the full ad viewing -> timer paused -> reward callback loop!
    if (!AdConfig.isPlatformSupported || !_isRewardedReady || _rewardedAd == null) {
      if (context != null && context.mounted) {
        final title = purpose == AdPurpose.revive ? 'Revive & Continue' : 'Hint Reward';
        final desc = purpose == AdPurpose.revive
            ? 'Watch this test ad to recover 2 hearts and keep your current puzzle progress.'
            : 'Watch this test ad to reveal the free untangled arrow on the board.';
        final earned = await LocalAdSimulatorDialog.show(
          context,
          title: title,
          description: desc,
          durationSeconds: 3,
        );
        _logAnalytics('simulated_ad_completed', {'purpose': purpose.name, 'rewardEarned': earned});
        return earned;
      }
      loadRewarded();
      return false;
    }

    if (_isShowingAd) return false;

    final completer = Completer<bool>();
    var rewardEarned = false;
    _isShowingAd = true;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _logAnalytics('ad_shown', {'purpose': purpose.name});
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedReady = false;
        _rewardedNotifier.value = false;
        _isShowingAd = false;
        loadRewarded(); // Preload next
        if (!completer.isCompleted) completer.complete(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedReady = false;
        _rewardedNotifier.value = false;
        _isShowingAd = false;
        _logAnalytics('ad_failed_to_show', {'error': error.message});
        loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        rewardEarned = true;
        _logAnalytics('reward_earned', {'purpose': purpose.name, 'amount': reward.amount});
      },
    );

    return completer.future;
  }

  @override
  Widget buildBannerWidget({Key? key}) {
    return AdBannerWidget(key: key);
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedNotifier.dispose();
  }

  void _logAnalytics(String event, [Map<String, dynamic>? params]) {
    debugPrint('[Analytics Hook] $event: ${params ?? {}}');
  }
}

/// Adaptive banner widget with automatic collapse on failure.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final adUnitId = AdConfig.bannerAdUnitId;
    if (adUnitId.isEmpty) return;

    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null) return;

    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _isLoaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// Fake implementation of AdService for tests and non-mobile preview.
class FakeAdService implements AdService {
  bool shouldGrantReward;
  bool isReady;
  final ValueNotifier<bool> _readyNotifier;

  FakeAdService({this.shouldGrantReward = true, this.isReady = true})
      : _readyNotifier = ValueNotifier<bool>(isReady);

  @override
  bool get isRewardedReady => isReady;

  @override
  ValueListenable<bool> get rewardedReadyListenable => _readyNotifier;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestConsent() async {}

  @override
  Future<bool> showRewarded({required AdPurpose purpose, BuildContext? context}) async {
    if (!isReady) return false;
    if (context != null && context.mounted) {
      return LocalAdSimulatorDialog.show(
        context,
        title: purpose == AdPurpose.revive ? 'Revive & Continue' : 'Hint Reward',
        description: 'Testing rewarded ads in development environment.',
        durationSeconds: 1,
      );
    }
    return shouldGrantReward;
  }

  @override
  Widget buildBannerWidget({Key? key}) => const SizedBox.shrink();

  @override
  void dispose() {
    _readyNotifier.dispose();
  }
}
