package com.easyads.easy_ads_sdk

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class EasyAdsSdkPluginTest {
    @Test
    fun onMethodCall_ping_returnsOk() {
        val plugin = EasyAdsSdkPlugin()
        val call = MethodCall("ping", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)
        Mockito.verify(mockResult).success("ok")
    }
}
