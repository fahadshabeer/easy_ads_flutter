package com.easyads.easy_ads_sdk

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EasyAdsSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var store: FacebookAdStore
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        store = FacebookAdStore { activity }
        channel = MethodChannel(binding.binaryMessenger, "easy_ads_sdk/facebook")
        channel.setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, "easy_ads_sdk/facebook_events")
            .setStreamHandler(store)
        binding.platformViewRegistry.registerViewFactory(
            "easy_ads_sdk/facebook_banner",
            FacebookViewFactory { id -> store.bannerView(id) },
        )
        binding.platformViewRegistry.registerViewFactory(
            "easy_ads_sdk/facebook_native",
            FacebookViewFactory { id -> store.nativeView(id) },
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "ping") {
            result.success("ok")
            return
        }
        if (!this::store.isInitialized) {
            result.error("not_attached", "Easy Ads is not attached to a Flutter engine.", null)
            return
        }
        store.handle(call, OnceResult(result))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

private class FacebookViewFactory(
    private val lookup: (String) -> android.view.View?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val id = (args as? Map<*, *>)?.get("id") as? String
        val view = id?.let(lookup)
        return if (view == null) EmptyPlatformView(context) else AttachedPlatformView(view)
    }
}
