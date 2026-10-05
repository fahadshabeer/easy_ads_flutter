import Flutter
import UIKit
import FBAudienceNetwork
import AppTrackingTransparency

public class EasyAdsSdkPlugin: NSObject, FlutterPlugin {
  private let store = FacebookAdStore()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = EasyAdsSdkPlugin()
    let channel = FlutterMethodChannel(
      name: "easy_ads_sdk/facebook",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(
      name: "easy_ads_sdk/facebook_events",
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance.store)
    registrar.register(
      FacebookViewFactory { id in instance.store.bannerView(id: id) },
      withId: "easy_ads_sdk/facebook_banner"
    )
    registrar.register(
      FacebookViewFactory { id in instance.store.nativeView(id: id) },
      withId: "easy_ads_sdk/facebook_native"
    )
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "ping":
      result("ok")
    case "initialize":
      store.initialize(
        advertiserTrackingEnabled: args["advertiserTrackingEnabled"] as? Bool ?? false,
        result: result
      )
    case "requestTracking":
      store.requestTracking(result: result)
    case "loadBanner":
      store.loadBanner(
        id: args.string("id"),
        placementId: args.string("placementId"),
        size: args["size"] as? String,
        result: result
      )
    case "loadNative":
      store.loadNative(
        id: args.string("id"),
        placementId: args.string("placementId"),
        result: result
      )
    case "loadInterstitial":
      store.loadInterstitial(
        id: args.string("id"),
        placementId: args.string("placementId"),
        result: result
      )
    case "showInterstitial":
      store.showInterstitial(id: args.string("id"), result: result)
    case "loadRewarded":
      store.loadRewarded(
        id: args.string("id"),
        placementId: args.string("placementId"),
        result: result
      )
    case "showRewarded":
      store.showRewarded(id: args.string("id"), result: result)
    case "loadRewardedInterstitial":
      store.loadRewardedInterstitial(
        id: args.string("id"),
        placementId: args.string("placementId"),
        result: result
      )
    case "showRewardedInterstitial":
      store.showRewardedInterstitial(id: args.string("id"), result: result)
    case "dispose":
      store.dispose(id: args.string("id"))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private extension Dictionary where Key == String {
  func string(_ key: String) -> String {
    let value = self[key] as? String
    return value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}

final class FacebookAdStore: NSObject, FlutterStreamHandler {
  private var events: FlutterEventSink?
  private var banners: [String: FBAdView] = [:]
  private var bannerDelegates: [String: BannerDelegate] = [:]
  private var natives: [String: FacebookNativeTemplate] = [:]
  private var nativeDelegates: [String: NativeDelegate] = [:]
  private var interstitials: [String: FBInterstitialAd] = [:]
  private var interstitialDelegates: [String: InterstitialDelegate] = [:]
  private var rewarded: [String: FBRewardedVideoAd] = [:]
  private var rewardedDelegates: [String: RewardedDelegate] = [:]
  private var rewardedInterstitials: [String: FBRewardedInterstitialAd] = [:]
  private var rewardedInterstitialDelegates: [String: RewardedInterstitialDelegate] = [:]

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.events = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    events = nil
    return nil
  }

  func bannerView(id: String) -> UIView? {
    banners[id]
  }

  func nativeView(id: String) -> UIView? {
    natives[id]
  }

  func initialize(advertiserTrackingEnabled: Bool, result: @escaping FlutterResult) {
    let trackingAllowed = advertiserTrackingEnabled && Self.trackingAuthorized
    FBAdSettings.setAdvertiserTrackingEnabled(trackingAllowed)
    FBAudienceNetworkAds.initialize(with: nil) { _ in
      DispatchQueue.main.async {
        result(nil)
      }
    }
  }

  func requestTracking(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      ATTrackingManager.requestTrackingAuthorization { status in
        let name: String
        switch status {
        case .authorized:
          name = "authorized"
        case .denied:
          name = "denied"
        case .restricted:
          name = "restricted"
        case .notDetermined:
          name = "notDetermined"
        @unknown default:
          name = "notDetermined"
        }
        DispatchQueue.main.async {
          result(name)
        }
      }
    } else {
      result("authorized")
    }
  }

  func loadBanner(id: String, placementId: String, size: String?, result: @escaping FlutterResult) {
    guard let controller = RootController.current() else {
      result(FlutterError(code: "no_controller", message: "Easy Ads could not find a view controller for the Facebook banner.", details: nil))
      return
    }
    disposeBanner(id)
    let reply = OnceReply(result)
    let adView = FBAdView(placementID: placementId, adSize: Self.bannerSize(size), rootViewController: controller)
    let delegate = BannerDelegate(
      onLoaded: { reply.success() },
      onFailed: { error in
        self.disposeBanner(id)
        reply.failure(error)
      },
      onClick: { self.emit(id: id, type: "clicked") },
      onImpression: { self.emit(id: id, type: "impression") }
    )
    adView.delegate = delegate
    banners[id] = adView
    bannerDelegates[id] = delegate
    adView.loadAd()
  }

  func loadNative(id: String, placementId: String, result: @escaping FlutterResult) {
    guard RootController.current() != nil else {
      result(FlutterError(code: "no_controller", message: "Easy Ads could not find a view controller for the Facebook native ad.", details: nil))
      return
    }
    disposeNative(id)
    let reply = OnceReply(result)
    let nativeAd = FBNativeAd(placementID: placementId)
    let delegate = NativeDelegate(
      onLoaded: { ad in
        guard let controller = RootController.current() else {
          reply.failureMessage("Easy Ads could not find a view controller for the Facebook native ad.")
          return
        }
        self.natives[id] = FacebookNativeTemplate(nativeAd: ad, root: controller)
        reply.success()
      },
      onFailed: { error in
        self.disposeNative(id)
        reply.failure(error)
      },
      onClick: { self.emit(id: id, type: "clicked") },
      onImpression: { self.emit(id: id, type: "impression") }
    )
    nativeAd.delegate = delegate
    nativeDelegates[id] = delegate
    nativeAd.loadAd()
  }

  func loadInterstitial(id: String, placementId: String, result: @escaping FlutterResult) {
    disposeInterstitial(id)
    let reply = OnceReply(result)
    let ad = FBInterstitialAd(placementID: placementId)
    let delegate = InterstitialDelegate(
      onLoaded: { reply.success() },
      onFailed: { error in
        if reply.finished {
          self.emit(id: id, type: "show_failed", message: error.localizedDescription, code: (error as NSError).code)
        } else {
          self.disposeInterstitial(id)
          reply.failure(error)
        }
      },
      onClick: { self.emit(id: id, type: "clicked") },
      onImpression: { self.emit(id: id, type: "impression") },
      onClosed: {
        self.disposeInterstitial(id)
        self.emit(id: id, type: "closed")
      }
    )
    ad.delegate = delegate
    interstitials[id] = ad
    interstitialDelegates[id] = delegate
    ad.load()
  }

  func showInterstitial(id: String, result: @escaping FlutterResult) {
    guard let ad = interstitials[id], ad.isAdValid, let controller = RootController.current() else {
      result(FlutterError(code: "not_ready", message: "Facebook interstitial is not ready to show.", details: nil))
      return
    }
    let shown = ad.show(fromRootViewController: controller)
    if shown {
      result(nil)
    } else {
      result(FlutterError(code: "show_failed", message: "Facebook interstitial could not be shown.", details: nil))
    }
  }

  func loadRewarded(id: String, placementId: String, result: @escaping FlutterResult) {
    disposeRewarded(id)
    let reply = OnceReply(result)
    let ad = FBRewardedVideoAd(placementID: placementId)
    let delegate = RewardedDelegate(
      onLoaded: { reply.success() },
      onFailed: { error in
        if reply.finished {
          self.emit(id: id, type: "show_failed", message: error.localizedDescription, code: (error as NSError).code)
        } else {
          self.disposeRewarded(id)
          reply.failure(error)
        }
      },
      onClick: { self.emit(id: id, type: "clicked") },
      onImpression: { self.emit(id: id, type: "impression") },
      onReward: {
        self.emit(id: id, type: "reward", rewardAmount: 1, rewardType: "reward")
      },
      onClosed: {
        self.disposeRewarded(id)
        self.emit(id: id, type: "closed")
      }
    )
    ad.delegate = delegate
    rewarded[id] = ad
    rewardedDelegates[id] = delegate
    ad.load()
  }

  func showRewarded(id: String, result: @escaping FlutterResult) {
    guard let ad = rewarded[id], ad.isAdValid, let controller = RootController.current() else {
      result(FlutterError(code: "not_ready", message: "Facebook rewarded ad is not ready to show.", details: nil))
      return
    }
    let shown = ad.show(fromRootViewController: controller)
    if shown {
      result(nil)
    } else {
      result(FlutterError(code: "show_failed", message: "Facebook rewarded ad could not be shown.", details: nil))
    }
  }

  func loadRewardedInterstitial(id: String, placementId: String, result: @escaping FlutterResult) {
    disposeRewardedInterstitial(id)
    let reply = OnceReply(result)
    let ad = FBRewardedInterstitialAd(placementID: placementId)
    let delegate = RewardedInterstitialDelegate(
      onLoaded: { reply.success() },
      onFailed: { error in
        if reply.finished {
          self.emit(id: id, type: "show_failed", message: error.localizedDescription, code: (error as NSError).code)
        } else {
          self.disposeRewardedInterstitial(id)
          reply.failure(error)
        }
      },
      onClick: { self.emit(id: id, type: "clicked") },
      onImpression: { self.emit(id: id, type: "impression") },
      onReward: {
        self.emit(id: id, type: "reward", rewardAmount: 1, rewardType: "reward")
      },
      onClosed: {
        self.disposeRewardedInterstitial(id)
        self.emit(id: id, type: "closed")
      }
    )
    ad.delegate = delegate
    rewardedInterstitials[id] = ad
    rewardedInterstitialDelegates[id] = delegate
    ad.load()
  }

  func showRewardedInterstitial(id: String, result: @escaping FlutterResult) {
    guard let ad = rewardedInterstitials[id], ad.isAdValid, let controller = RootController.current() else {
      result(FlutterError(code: "not_ready", message: "Facebook rewarded interstitial is not ready to show.", details: nil))
      return
    }
    let shown = ad.show(fromRootViewController: controller, animated: true)
    if shown {
      result(nil)
    } else {
      result(FlutterError(code: "show_failed", message: "Facebook rewarded interstitial could not be shown.", details: nil))
    }
  }

  func dispose(id: String) {
    disposeBanner(id)
    disposeNative(id)
    disposeInterstitial(id)
    disposeRewarded(id)
    disposeRewardedInterstitial(id)
  }

  private func disposeBanner(_ id: String) {
    banners[id]?.removeFromSuperview()
    banners.removeValue(forKey: id)
    bannerDelegates.removeValue(forKey: id)
  }

  private func disposeNative(_ id: String) {
    natives[id]?.unregister()
    natives[id]?.removeFromSuperview()
    natives.removeValue(forKey: id)
    nativeDelegates.removeValue(forKey: id)
  }

  private func disposeInterstitial(_ id: String) {
    interstitials.removeValue(forKey: id)
    interstitialDelegates.removeValue(forKey: id)
  }

  private func disposeRewarded(_ id: String) {
    rewarded.removeValue(forKey: id)
    rewardedDelegates.removeValue(forKey: id)
  }

  private func disposeRewardedInterstitial(_ id: String) {
    rewardedInterstitials.removeValue(forKey: id)
    rewardedInterstitialDelegates.removeValue(forKey: id)
  }

  private func emit(
    id: String,
    type: String,
    message: String? = nil,
    code: Int? = nil,
    rewardAmount: Int? = nil,
    rewardType: String? = nil
  ) {
    var payload: [String: Any] = ["id": id, "type": type]
    if let message { payload["message"] = message }
    if let code { payload["code"] = code }
    if let rewardAmount { payload["rewardAmount"] = rewardAmount }
    if let rewardType { payload["rewardType"] = rewardType }
    DispatchQueue.main.async {
      self.events?(payload)
    }
  }

  private static var trackingAuthorized: Bool {
    if #available(iOS 14, *) {
      return ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
    return true
  }

  private static func bannerSize(_ name: String?) -> FBAdSize {
    switch name {
    case "large":
      return kFBAdSizeHeight90Banner
    case "mediumRectangle":
      return kFBAdSizeHeight250Rectangle
    default:
      return kFBAdSizeHeight50Banner
    }
  }
}

private final class OnceReply {
  private let result: FlutterResult
  private var done = false
  var finished: Bool { done }

  init(_ result: @escaping FlutterResult) {
    self.result = result
  }

  func success() {
    guard !done else { return }
    done = true
    DispatchQueue.main.async {
      self.result(nil)
    }
  }

  func failure(_ error: Error) {
    let nsError = error as NSError
    failureMessage(nsError.localizedDescription, code: nsError.code)
  }

  func failureMessage(_ message: String, code: Int? = nil) {
    guard !done else { return }
    done = true
    DispatchQueue.main.async {
      self.result(
        FlutterError(
          code: "load_failed",
          message: message,
          details: code == nil ? nil : ["code": code!]
        )
      )
    }
  }
}

private final class BannerDelegate: NSObject, FBAdViewDelegate {
  let onLoaded: () -> Void
  let onFailed: (Error) -> Void
  let onClick: () -> Void
  let onImpression: () -> Void

  init(
    onLoaded: @escaping () -> Void,
    onFailed: @escaping (Error) -> Void,
    onClick: @escaping () -> Void,
    onImpression: @escaping () -> Void
  ) {
    self.onLoaded = onLoaded
    self.onFailed = onFailed
    self.onClick = onClick
    self.onImpression = onImpression
  }

  func adViewDidLoad(_ adView: FBAdView) {
    onLoaded()
  }

  func adView(_ adView: FBAdView, didFailWithError error: Error) {
    onFailed(error)
  }

  func adViewDidClick(_ adView: FBAdView) {
    onClick()
  }

  func adViewWillLogImpression(_ adView: FBAdView) {
    onImpression()
  }
}

private final class InterstitialDelegate: NSObject, FBInterstitialAdDelegate {
  let onLoaded: () -> Void
  let onFailed: (Error) -> Void
  let onClick: () -> Void
  let onImpression: () -> Void
  let onClosed: () -> Void

  init(
    onLoaded: @escaping () -> Void,
    onFailed: @escaping (Error) -> Void,
    onClick: @escaping () -> Void,
    onImpression: @escaping () -> Void,
    onClosed: @escaping () -> Void
  ) {
    self.onLoaded = onLoaded
    self.onFailed = onFailed
    self.onClick = onClick
    self.onImpression = onImpression
    self.onClosed = onClosed
  }

  func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) {
    onLoaded()
  }

  func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) {
    onFailed(error)
  }

  func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) {
    onClick()
  }

  func interstitialAdWillLogImpression(_ interstitialAd: FBInterstitialAd) {
    onImpression()
  }

  func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) {
    onClosed()
  }
}

private final class RewardedDelegate: NSObject, FBRewardedVideoAdDelegate {
  let onLoaded: () -> Void
  let onFailed: (Error) -> Void
  let onClick: () -> Void
  let onImpression: () -> Void
  let onReward: () -> Void
  let onClosed: () -> Void

  init(
    onLoaded: @escaping () -> Void,
    onFailed: @escaping (Error) -> Void,
    onClick: @escaping () -> Void,
    onImpression: @escaping () -> Void,
    onReward: @escaping () -> Void,
    onClosed: @escaping () -> Void
  ) {
    self.onLoaded = onLoaded
    self.onFailed = onFailed
    self.onClick = onClick
    self.onImpression = onImpression
    self.onReward = onReward
    self.onClosed = onClosed
  }

  func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) {
    onLoaded()
  }

  func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) {
    onFailed(error)
  }

  func rewardedVideoAdDidClick(_ rewardedVideoAd: FBRewardedVideoAd) {
    onClick()
  }

  func rewardedVideoAdWillLogImpression(_ rewardedVideoAd: FBRewardedVideoAd) {
    onImpression()
  }

  func rewardedVideoAdVideoComplete(_ rewardedVideoAd: FBRewardedVideoAd) {
    onReward()
  }

  func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
    onClosed()
  }
}

private final class RewardedInterstitialDelegate: NSObject, FBRewardedInterstitialAdDelegate {
  let onLoaded: () -> Void
  let onFailed: (Error) -> Void
  let onClick: () -> Void
  let onImpression: () -> Void
  let onReward: () -> Void
  let onClosed: () -> Void

  init(
    onLoaded: @escaping () -> Void,
    onFailed: @escaping (Error) -> Void,
    onClick: @escaping () -> Void,
    onImpression: @escaping () -> Void,
    onReward: @escaping () -> Void,
    onClosed: @escaping () -> Void
  ) {
    self.onLoaded = onLoaded
    self.onFailed = onFailed
    self.onClick = onClick
    self.onImpression = onImpression
    self.onReward = onReward
    self.onClosed = onClosed
  }

  func rewardedInterstitialAdDidLoad(_ rewardedInterstitialAd: FBRewardedInterstitialAd) {
    onLoaded()
  }

  func rewardedInterstitialAd(_ rewardedInterstitialAd: FBRewardedInterstitialAd, didFailWithError error: Error) {
    onFailed(error)
  }

  func rewardedInterstitialAdDidClick(_ rewardedInterstitialAd: FBRewardedInterstitialAd) {
    onClick()
  }

  func rewardedInterstitialAdWillLogImpression(_ rewardedInterstitialAd: FBRewardedInterstitialAd) {
    onImpression()
  }

  func rewardedInterstitialAdVideoComplete(_ rewardedInterstitialAd: FBRewardedInterstitialAd) {
    onReward()
  }

  func rewardedInterstitialAdDidClose(_ rewardedInterstitialAd: FBRewardedInterstitialAd) {
    onClosed()
  }
}

private final class NativeDelegate: NSObject, FBNativeAdDelegate {
  let onLoaded: (FBNativeAd) -> Void
  let onFailed: (Error) -> Void
  let onClick: () -> Void
  let onImpression: () -> Void

  init(
    onLoaded: @escaping (FBNativeAd) -> Void,
    onFailed: @escaping (Error) -> Void,
    onClick: @escaping () -> Void,
    onImpression: @escaping () -> Void
  ) {
    self.onLoaded = onLoaded
    self.onFailed = onFailed
    self.onClick = onClick
    self.onImpression = onImpression
  }

  func nativeAdDidLoad(_ nativeAd: FBNativeAd) {
    onLoaded(nativeAd)
  }

  func nativeAd(_ nativeAd: FBNativeAd, didFailWithError error: Error) {
    onFailed(error)
  }

  func nativeAdDidClick(_ nativeAd: FBNativeAd) {
    onClick()
  }

  func nativeAdWillLogImpression(_ nativeAd: FBNativeAd) {
    onImpression()
  }
}

/// Built-in native layout. The app does not provide its own XML or Swift view.
final class FacebookNativeTemplate: UIView {
  private let nativeAd: FBNativeAd
  private let icon = FBMediaView()
  private let media = FBMediaView()
  private let title = UILabel()
  private let body = UILabel()
  private let sponsored = UILabel()
  private let callToAction = UIButton(type: .system)
  private let options = FBAdOptionsView()

  init(nativeAd: FBNativeAd, root: UIViewController) {
    self.nativeAd = nativeAd
    super.init(frame: .zero)
    backgroundColor = UIColor.secondarySystemBackground
    title.font = .boldSystemFont(ofSize: 16)
    title.numberOfLines = 1
    body.font = .systemFont(ofSize: 14)
    body.numberOfLines = 2
    sponsored.font = .systemFont(ofSize: 12)
    sponsored.textColor = .secondaryLabel
    sponsored.text = "Sponsored"
    callToAction.setTitleColor(.white, for: .normal)
    callToAction.backgroundColor = .systemBlue
    callToAction.layer.cornerRadius = 8
    callToAction.titleLabel?.font = .boldSystemFont(ofSize: 15)
    icon.clipsToBounds = true
    media.clipsToBounds = true

    title.text = nativeAd.headline
    body.text = nativeAd.bodyText
    callToAction.setTitle(nativeAd.callToAction, for: .normal)
    options.nativeAd = nativeAd

    for item in [icon, title, sponsored, options, media, body, callToAction] {
      item.translatesAutoresizingMaskIntoConstraints = true
      addSubview(item)
    }

    nativeAd.registerView(
      forInteraction: self,
      mediaView: media,
      iconView: icon,
      viewController: root,
      clickableViews: [callToAction, media]
    )
  }

  required init?(coder: NSCoder) {
    return nil
  }

  func unregister() {
    nativeAd.unregisterView()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    icon.frame = CGRect(x: 12, y: 12, width: 40, height: 40)
    options.frame = CGRect(x: width - 28, y: 8, width: 16, height: 16)
    title.frame = CGRect(x: 60, y: 12, width: width - 96, height: 20)
    sponsored.frame = CGRect(x: 60, y: 34, width: width - 96, height: 16)
    let mediaHeight = max(160, bounds.height - 156)
    media.frame = CGRect(x: 12, y: 64, width: width - 24, height: mediaHeight)
    body.frame = CGRect(x: 12, y: media.frame.maxY + 8, width: width - 24, height: 36)
    callToAction.frame = CGRect(x: 12, y: bounds.height - 48, width: width - 24, height: 36)
  }
}

private enum RootController {
  static func current() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}

private final class FacebookViewFactory: NSObject, FlutterPlatformViewFactory {
  private let lookup: (String) -> UIView?

  init(lookup: @escaping (String) -> UIView?) {
    self.lookup = lookup
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let id = (args as? [String: Any])?["id"] as? String
    let child = id.flatMap(lookup) ?? UIView(frame: frame)
    return FacebookPlatformView(child: child)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class FacebookPlatformView: NSObject, FlutterPlatformView {
  private let child: UIView

  init(child: UIView) {
    self.child = child
  }

  func view() -> UIView {
    child
  }
}
