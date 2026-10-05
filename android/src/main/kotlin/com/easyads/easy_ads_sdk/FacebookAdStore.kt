package com.easyads.easy_ads_sdk

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.facebook.ads.Ad
import com.facebook.ads.AdError
import com.facebook.ads.AdListener
import com.facebook.ads.AdSize
import com.facebook.ads.AdView
import com.facebook.ads.AudienceNetworkAds
import com.facebook.ads.InterstitialAd
import com.facebook.ads.InterstitialAdListener
import com.facebook.ads.NativeAd
import com.facebook.ads.NativeAdListener
import com.facebook.ads.NativeAdView
import com.facebook.ads.RewardedInterstitialAd
import com.facebook.ads.RewardedInterstitialAdListener
import com.facebook.ads.RewardedVideoAd
import com.facebook.ads.RewardedVideoAdListener
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

internal class OnceResult(private val result: MethodChannel.Result) {
    private val done = AtomicBoolean(false)

    fun success() {
        if (done.compareAndSet(false, true)) {
            result.success(null)
        }
    }

    fun error(code: String, message: String, networkCode: Int? = null) {
        if (done.compareAndSet(false, true)) {
            val details = if (networkCode == null) null else mapOf("code" to networkCode)
            result.error(code, message, details)
        }
    }
}

private class NativeEntry(val nativeAd: NativeAd, val view: View)

/**
 * Holds Meta Audience Network objects and talks to Flutter.
 * AdMob stays in Dart through google_mobile_ads.
 */
internal class FacebookAdStore(
    private val activityProvider: () -> Activity?,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null
    private val banners = HashMap<String, AdView>()
    private val natives = HashMap<String, NativeEntry>()
    private val interstitials = HashMap<String, InterstitialAd>()
    private val rewardedVideos = HashMap<String, RewardedVideoAd>()
    private val rewardedInterstitials = HashMap<String, RewardedInterstitialAd>()

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    fun bannerView(id: String): View? = banners[id]

    fun nativeView(id: String): View? = natives[id]?.view

    fun handle(call: MethodCall, result: OnceResult) {
        val args = call.arguments as? Map<*, *>
        when (call.method) {
            "initialize" -> initialize(result)
            "loadBanner" -> loadBanner(
                args.string("id"),
                args.string("placementId"),
                args?.get("size") as? String,
                result,
            )
            "loadNative" -> loadNative(args.string("id"), args.string("placementId"), result)
            "loadInterstitial" -> loadInterstitial(
                args.string("id"),
                args.string("placementId"),
                result,
            )
            "showInterstitial" -> showInterstitial(args.string("id"), result)
            "loadRewarded" -> loadRewarded(args.string("id"), args.string("placementId"), result)
            "showRewarded" -> showRewarded(args.string("id"), result)
            "loadRewardedInterstitial" -> loadRewardedInterstitial(
                args.string("id"),
                args.string("placementId"),
                result,
            )
            "showRewardedInterstitial" -> showRewardedInterstitial(args.string("id"), result)
            "dispose" -> {
                dispose(args.string("id"))
                result.success()
            }
            else -> result.error("not_implemented", "Unknown method ${call.method}.")
        }
    }

    private fun initialize(result: OnceResult) {
        val activity = activityProvider()
        if (activity == null) {
            result.error(
                "no_activity",
                "Easy Ads needs a foreground Activity before Facebook can initialize.",
            )
            return
        }
        main {
            try {
                if (!AudienceNetworkAds.isInitialized(activity)) {
                    AudienceNetworkAds.initialize(activity)
                }
                result.success()
            } catch (error: Throwable) {
                Log.w(TAG, "Facebook initialize failed", error)
                result.error(
                    "facebook_init_failed",
                    error.message ?: "Facebook failed to initialize.",
                )
            }
        }
    }

    private fun loadBanner(id: String, placementId: String, sizeName: String?, result: OnceResult) {
        val activity = activityProvider() ?: return missingActivity(result)
        main {
            destroyBanner(id)
            val adView = AdView(activity, placementId, bannerSize(sizeName))
            banners[id] = adView
            adView.loadAd(
                adView.buildLoadAdConfig().withAdListener(
                    object : AdListener {
                        override fun onError(ad: Ad, error: AdError) {
                            destroyBanner(id)
                            result.error("load_failed", error.errorMessage, error.errorCode)
                        }

                        override fun onAdLoaded(ad: Ad) {
                            result.success()
                        }

                        override fun onAdClicked(ad: Ad) {
                            emit(id, "clicked")
                        }

                        override fun onLoggingImpression(ad: Ad) {
                            emit(id, "impression")
                        }
                    },
                ).build(),
            )
        }
    }

    private fun loadNative(id: String, placementId: String, result: OnceResult) {
        val activity = activityProvider() ?: return missingActivity(result)
        main {
            destroyNative(id)
            val nativeAd = NativeAd(activity, placementId)
            nativeAd.loadAd(
                nativeAd.buildLoadAdConfig().withAdListener(
                    object : NativeAdListener {
                        override fun onMediaDownloaded(ad: Ad) = Unit

                        override fun onError(ad: Ad, error: AdError) {
                            destroyNative(id)
                            nativeAd.destroy()
                            result.error("load_failed", error.errorMessage, error.errorCode)
                        }

                        override fun onAdLoaded(ad: Ad) {
                            val rendered = NativeAdView.render(activity, nativeAd)
                            if (rendered == null) {
                                nativeAd.destroy()
                                result.error(
                                    "load_failed",
                                    "Facebook could not render its native ad template.",
                                )
                                return
                            }
                            natives[id] = NativeEntry(nativeAd, rendered)
                            result.success()
                        }

                        override fun onAdClicked(ad: Ad) {
                            emit(id, "clicked")
                        }

                        override fun onLoggingImpression(ad: Ad) {
                            emit(id, "impression")
                        }
                    },
                ).build(),
            )
        }
    }

    private fun loadInterstitial(id: String, placementId: String, result: OnceResult) {
        val activity = activityProvider() ?: return missingActivity(result)
        main {
            interstitials.remove(id)?.destroy()
            val ad = InterstitialAd(activity, placementId)
            interstitials[id] = ad
            var loaded = false
            ad.loadAd(
                ad.buildLoadAdConfig().withAdListener(
                    object : InterstitialAdListener {
                        override fun onInterstitialDisplayed(ad: Ad) = Unit

                        override fun onInterstitialDismissed(ad: Ad) {
                            interstitials.remove(id)?.destroy()
                            emit(id, "closed")
                        }

                        override fun onError(ad: Ad, error: AdError) {
                            if (!loaded) {
                                interstitials.remove(id)?.destroy()
                                result.error("load_failed", error.errorMessage, error.errorCode)
                            } else {
                                emit(
                                    id,
                                    "show_failed",
                                    mapOf(
                                        "message" to error.errorMessage,
                                        "code" to error.errorCode,
                                    ),
                                )
                            }
                        }

                        override fun onAdLoaded(ad: Ad) {
                            loaded = true
                            result.success()
                        }

                        override fun onAdClicked(ad: Ad) {
                            emit(id, "clicked")
                        }

                        override fun onLoggingImpression(ad: Ad) {
                            emit(id, "impression")
                        }
                    },
                ).build(),
            )
        }
    }

    private fun showInterstitial(id: String, result: OnceResult) {
        val ad = interstitials[id]
        if (ad == null || !ad.isAdLoaded || ad.isAdInvalidated) {
            result.error("not_ready", "Facebook interstitial is not ready to show.")
            return
        }
        ad.show()
        result.success()
    }

    private fun loadRewarded(id: String, placementId: String, result: OnceResult) {
        val activity = activityProvider() ?: return missingActivity(result)
        main {
            rewardedVideos.remove(id)?.destroy()
            val ad = RewardedVideoAd(activity, placementId)
            rewardedVideos[id] = ad
            var loaded = false
            ad.loadAd(
                ad.buildLoadAdConfig().withAdListener(
                    object : RewardedVideoAdListener {
                        override fun onError(ad: Ad, error: AdError) {
                            if (!loaded) {
                                rewardedVideos.remove(id)?.destroy()
                                result.error("load_failed", error.errorMessage, error.errorCode)
                            } else {
                                emit(
                                    id,
                                    "show_failed",
                                    mapOf(
                                        "message" to error.errorMessage,
                                        "code" to error.errorCode,
                                    ),
                                )
                            }
                        }

                        override fun onAdLoaded(ad: Ad) {
                            loaded = true
                            result.success()
                        }

                        override fun onAdClicked(ad: Ad) {
                            emit(id, "clicked")
                        }

                        override fun onLoggingImpression(ad: Ad) {
                            emit(id, "impression")
                        }

                        override fun onRewardedVideoCompleted() {
                            emit(
                                id,
                                "reward",
                                mapOf("rewardAmount" to 1, "rewardType" to "reward"),
                            )
                        }

                        override fun onRewardedVideoClosed() {
                            rewardedVideos.remove(id)?.destroy()
                            emit(id, "closed")
                        }
                    },
                ).build(),
            )
        }
    }

    private fun showRewarded(id: String, result: OnceResult) {
        val ad = rewardedVideos[id]
        if (ad == null || !ad.isAdLoaded || ad.isAdInvalidated) {
            result.error("not_ready", "Facebook rewarded ad is not ready to show.")
            return
        }
        if (!ad.show()) {
            result.error("show_failed", "Facebook rewarded ad could not be shown.")
            return
        }
        result.success()
    }

    private fun loadRewardedInterstitial(id: String, placementId: String, result: OnceResult) {
        val activity = activityProvider() ?: return missingActivity(result)
        main {
            rewardedInterstitials.remove(id)?.destroy()
            val ad = RewardedInterstitialAd(activity, placementId)
            rewardedInterstitials[id] = ad
            var loaded = false
            ad.loadAd(
                ad.buildLoadAdConfig().withAdListener(
                    object : RewardedInterstitialAdListener {
                        override fun onError(ad: Ad, error: AdError) {
                            if (!loaded) {
                                rewardedInterstitials.remove(id)?.destroy()
                                result.error("load_failed", error.errorMessage, error.errorCode)
                            } else {
                                emit(
                                    id,
                                    "show_failed",
                                    mapOf(
                                        "message" to error.errorMessage,
                                        "code" to error.errorCode,
                                    ),
                                )
                            }
                        }

                        override fun onAdLoaded(ad: Ad) {
                            loaded = true
                            result.success()
                        }

                        override fun onAdClicked(ad: Ad) {
                            emit(id, "clicked")
                        }

                        override fun onLoggingImpression(ad: Ad) {
                            emit(id, "impression")
                        }

                        override fun onRewardedInterstitialCompleted() {
                            emit(
                                id,
                                "reward",
                                mapOf("rewardAmount" to 1, "rewardType" to "reward"),
                            )
                        }

                        override fun onRewardedInterstitialClosed() {
                            rewardedInterstitials.remove(id)?.destroy()
                            emit(id, "closed")
                        }
                    },
                ).build(),
            )
        }
    }

    private fun showRewardedInterstitial(id: String, result: OnceResult) {
        val ad = rewardedInterstitials[id]
        if (ad == null || !ad.isAdLoaded || ad.isAdInvalidated) {
            result.error("not_ready", "Facebook rewarded interstitial is not ready to show.")
            return
        }
        if (!ad.show()) {
            result.error("show_failed", "Facebook rewarded interstitial could not be shown.")
            return
        }
        result.success()
    }

    fun dispose(id: String) {
        main {
            destroyBanner(id)
            destroyNative(id)
            interstitials.remove(id)?.destroy()
            rewardedVideos.remove(id)?.destroy()
            rewardedInterstitials.remove(id)?.destroy()
        }
    }

    private fun destroyBanner(id: String) {
        banners.remove(id)?.let { adView ->
            (adView.parent as? ViewGroup)?.removeView(adView)
            adView.destroy()
        }
    }

    private fun destroyNative(id: String) {
        natives.remove(id)?.let { entry ->
            (entry.view.parent as? ViewGroup)?.removeView(entry.view)
            entry.nativeAd.destroy()
        }
    }

    private fun emit(id: String, type: String, extras: Map<String, Any?> = emptyMap()) {
        main {
            val payload = HashMap<String, Any?>()
            payload["id"] = id
            payload["type"] = type
            payload.putAll(extras)
            events?.success(payload)
        }
    }

    private fun missingActivity(result: OnceResult) {
        result.error(
            "no_activity",
            "Easy Ads needs a foreground Activity before it can load a Facebook ad.",
        )
    }

    private fun bannerSize(name: String?): AdSize {
        return when (name) {
            "large" -> AdSize.BANNER_HEIGHT_90
            "mediumRectangle" -> AdSize.RECTANGLE_HEIGHT_250
            else -> AdSize.BANNER_HEIGHT_50
        }
    }

    private fun main(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    private fun Map<*, *>?.string(key: String): String {
        val value = this?.get(key) as? String
        return value?.trim().orEmpty()
    }

    private companion object {
        const val TAG = "EasyAds"
    }
}

internal class AttachedPlatformView(child: View) : io.flutter.plugin.platform.PlatformView {
    private val container = FrameLayout(child.context)

    init {
        (child.parent as? ViewGroup)?.removeView(child)
        container.addView(
            child,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )
    }

    override fun getView(): View = container

    override fun dispose() {
        (container.getChildAt(0)?.parent as? ViewGroup)?.removeView(container.getChildAt(0))
    }
}

internal class EmptyPlatformView(context: android.content.Context) :
    io.flutter.plugin.platform.PlatformView {
    private val view = FrameLayout(context)

    override fun getView(): View = view

    override fun dispose() = Unit
}
