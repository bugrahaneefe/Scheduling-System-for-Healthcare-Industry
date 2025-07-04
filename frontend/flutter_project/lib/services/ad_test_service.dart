import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;

  /// Rastgele olasılıkla reklam gösterimi kontrolü
  static bool _shouldShowAd(int chancePercent) {
    final random = Random();
    return random.nextInt(100) < chancePercent;
  }

  /// Interstitial reklamı yükle ve göster
  static void maybeShowInterstitialAd({
    int chancePercent = 50,
    void Function()? onAdDismissed,
  }) {
    if (!_shouldShowAd(chancePercent)) return;

    InterstitialAd.load(
      adUnitId:
          'ca-app-pub-4424526592569602/5504881576', // Real iOS interstitial
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialAd!
              .fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onAdDismissed?.call();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
            },
          );
          _interstitialAd!.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  /// Rewarded video reklamı yükle ve göster
  static void maybeShowRewardedAd({
    int chancePercent = 30,
    required void Function() onRewardEarned,
  }) {
    if (!_shouldShowAd(chancePercent)) return;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-4424526592569602/5207985210', // Real iOS rewarded
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
            },
          );
          _rewardedAd!.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              onRewardEarned();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('RewardedAd failed to load: $error');
        },
      ),
    );
  }
}
