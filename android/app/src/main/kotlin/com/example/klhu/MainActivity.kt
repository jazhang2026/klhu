package com.example.klhu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /**
     * The render's platform half (spec 012, `klhu/video_encoder`). Registered
     * here because the render is the reader's own feature and the app has no
     * other native surface — the Flutter engine's binary messenger is all it
     * needs. Nothing else is added to the activity.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VideoEncoderPlugin().register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
