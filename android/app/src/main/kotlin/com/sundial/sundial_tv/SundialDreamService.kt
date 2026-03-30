package com.sundial.sundial_tv

import android.service.dreams.DreamService
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Android screensaver (Daydream) that renders the Sundial clock
 * via an embedded Flutter engine.
 *
 * Works on all Android devices that support DreamService (API 17+):
 *   • Android TV / Google TV
 *   • Phones & tablets (Settings → Display → Screen saver)
 *   • Chromebooks
 *   • Android Auto head units (dock mode)
 *
 * On Android TV 12+ / Google TV, the system UI no longer exposes
 * third-party screensaver selection. Users must set it via ADB:
 *
 *   adb shell settings put secure screensaver_components \
 *       com.connectio.sundial/com.sundial.sundial_tv.SundialDreamService
 */
class SundialDreamService : DreamService() {

    private var flutterEngine: FlutterEngine? = null
    private var flutterView: FlutterView? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()

        // Standard screensaver behaviour: exit on any touch / D-pad input
        isInteractive = false
        isFullscreen = true
        isScreenBright = true

        // Stand up a dedicated Flutter engine for the dream
        flutterEngine = FlutterEngine(this).also { engine ->
            GeneratedPluginRegistrant.registerWith(engine)

            // Register the platform channel so Dart can detect TV vs phone
            MainActivity.registerPlatformChannel(engine, this)

            // The Dart side reads this route to know it's running as a
            // screensaver and hides interactive UI (slider, buttons, etc.)
            engine.navigationChannel.setInitialRoute("/screensaver")

            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
        }

        // Attach a FlutterView to the dream window
        flutterView = FlutterView(this).also { view ->
            view.attachToFlutterEngine(flutterEngine!!)
            setContentView(view)
        }
    }

    override fun onDreamingStopped() {
        super.onDreamingStopped()
    }

    override fun onDetachedFromWindow() {
        flutterView?.detachFromFlutterEngine()
        flutterEngine?.destroy()
        flutterView = null
        flutterEngine = null
        super.onDetachedFromWindow()
    }
}
