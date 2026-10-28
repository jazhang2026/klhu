package com.example.klhu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /**
     * The app's platform halves (spec 012). Registered here because the video
     * is the reader's own feature and the app has no other native surface — the
     * Flutter engine's binary messenger and its platform view registry are all
     * it needs. Nothing else is added to the activity.
     *
     * Three of them: the render's encoder, the library the reader keeps a video
     * in (and hands it to the share list from), and the picture the review and
     * a kept video are watched on.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        VideoEncoderPlugin().register(messenger)
        VideoFileStore.register(messenger, this, this)
        VideoPlayerView.register(messenger)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            VideoPlayerView.VIEW_TYPE,
            VideoPlayerViewFactory(messenger),
        )
    }
}
