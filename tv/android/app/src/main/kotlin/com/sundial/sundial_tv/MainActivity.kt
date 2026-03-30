package com.sundial.sundial_tv

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerPlatformChannel(flutterEngine, this)
    }

    companion object {
        /**
         * Registers the "com.connectio.sundial/platform" MethodChannel
         * so the Dart side can query whether this is a TV device.
         *
         * Shared between MainActivity and SundialDreamService.
         */
        fun registerPlatformChannel(engine: FlutterEngine, context: Context) {
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "com.connectio.sundial/platform"
            ).setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTelevision" -> {
                        val uiModeManager =
                            context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                        val isTV = uiModeManager.currentModeType ==
                                Configuration.UI_MODE_TYPE_TELEVISION
                        result.success(isTV)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
