import 'package:flutter/material.dart';
import 'package:easy_ads_sdk/easy_ads_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyAds.initialize(
    priority: EasyAdPriority.admob,
    facebook: const FacebookOptions(),
    testMode: true,
  );
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy Ads',
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  String _status = 'Ready';
  late final EasyInterstitialAd _interstitial = EasyInterstitialAd(
    admobAdUnitId: EasyTestIds.interstitial,
    facebookPlacementId: EasyTestIds.facebookInterstitial,
    onLoading: () => _setStatus('Interstitial loading'),
    onLoaded: (network) => _setStatus('Interstitial loaded from ${network.name}'),
    onError: (error) => _setStatus('Interstitial error: ${error.message}'),
    onClosed: () => _setStatus('Interstitial closed'),
  );
  late final EasyRewardedAd _rewarded = EasyRewardedAd(
    admobAdUnitId: EasyTestIds.rewarded,
    facebookPlacementId: EasyTestIds.facebookRewarded,
    onLoading: () => _setStatus('Rewarded loading'),
    onLoaded: (network) => _setStatus('Rewarded loaded from ${network.name}'),
    onError: (error) => _setStatus('Rewarded error: ${error.message}'),
    onClosed: () => _setStatus('Rewarded closed'),
    onReward: (reward) => _setStatus('Reward: ${reward.amount} ${reward.type}'),
  );
  late final EasyRewardedInterstitialAd _rewardedInterstitial =
      EasyRewardedInterstitialAd(
    admobAdUnitId: EasyTestIds.rewardedInterstitial,
    facebookPlacementId: EasyTestIds.facebookRewardedInterstitial,
    onLoading: () => _setStatus('Rewarded interstitial loading'),
    onLoaded: (network) =>
        _setStatus('Rewarded interstitial loaded from ${network.name}'),
    onError: (error) =>
        _setStatus('Rewarded interstitial error: ${error.message}'),
    onClosed: () => _setStatus('Rewarded interstitial closed'),
    onReward: (reward) =>
        _setStatus('Rewarded interstitial reward: ${reward.amount} ${reward.type}'),
  );

  void _setStatus(String value) {
    if (!mounted) {
      return;
    }
    setState(() => _status = value);
  }

  @override
  void dispose() {
    _interstitial.dispose();
    _rewarded.dispose();
    _rewardedInterstitial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Easy Ads')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_status),
          const SizedBox(height: 16),
          const Text('Native'),
          const SizedBox(height: 8),
          EasyNativeAd(
            admobAdUnitId: EasyTestIds.native,
            facebookPlacementId: EasyTestIds.facebookNative,
            onLoading: () => _setStatus('Native loading'),
            onLoaded: (network) => _setStatus('Native loaded from ${network.name}'),
            onError: (error) => _setStatus('Native error: ${error.message}'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _interstitial.load,
            child: const Text('Load interstitial'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _interstitial.show();
              } catch (error) {
                _setStatus('$error');
              }
            },
            child: const Text('Show interstitial'),
          ),
          FilledButton(
            onPressed: _rewarded.load,
            child: const Text('Load rewarded'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _rewarded.show();
              } catch (error) {
                _setStatus('$error');
              }
            },
            child: const Text('Show rewarded'),
          ),
          FilledButton(
            onPressed: _rewardedInterstitial.load,
            child: const Text('Load rewarded interstitial'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _rewardedInterstitial.show();
              } catch (error) {
                _setStatus('$error');
              }
            },
            child: const Text('Show rewarded interstitial'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: EasyBannerAd(
          admobAdUnitId: EasyTestIds.banner,
          facebookPlacementId: EasyTestIds.facebookBanner,
          onLoading: () => _setStatus('Banner loading'),
          onLoaded: (network) => _setStatus('Banner loaded from ${network.name}'),
          onError: (error) => _setStatus('Banner error: ${error.message}'),
        ),
      ),
    );
  }
}
