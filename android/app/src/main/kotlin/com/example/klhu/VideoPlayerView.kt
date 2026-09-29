package com.example.klhu

import android.content.Context
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.media.MediaPlayer
import android.net.Uri
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.widget.MediaController
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.min

/**
 * The playback view (spec 012 US3, contracts/video-player-protocol.md).
 *
 * The video is watched inside the app — at the review, and later from the
 * content's own video actions — so the keep / throw-away / share decision stays
 * on one screen (FR-021). The transport controls are the platform's own: this
 * app does not re-implement a scrubber, which is why the picture is a
 * `MediaPlayer` driven by a `MediaController` (D12).
 *
 * **A `TextureView`, not a `VideoView` (2026-09-28, D20).** The shipped view was
 * a `VideoView`, which is a `SurfaceView` inside — and a `SurfaceView` inside a
 * Flutter platform view never reaches the screen: the reader's own phone showed
 * the review's picture black with the sound playing, and the probe run of
 * 2026-09-28 reproduced it on `emulator-5554` with the same file the candidate
 * view drew (see `breakpoint.md` row 44: the shipped view's whole picture area
 * measured 98 % of pixels below luma 30, saturation 0, two distinct colours —
 * the candidate, 10 % dark, saturation 255, 273 colours). A `TextureView` is
 * composited like any other view, which is what Flutter's platform views need.
 *
 * The source is always a local file (the working copy) or a local library uri
 * (a kept video). A network uri is refused rather than handed to the player
 * (FR-013): this app has no account, no upload and no server (FR-023).
 *
 * Leaving the view stops and releases the player — that is rule 4 of the
 * contract, and it is what keeps a deleted video from playing on.
 */
@Suppress("DEPRECATION") // MediaController is the platform's own scrubber (D12).
class VideoPlayerView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    creationParams: Any?,
) : PlatformView, MethodChannel.MethodCallHandler, TextureView.SurfaceTextureListener {

    companion object {
        const val VIEW_TYPE = "klhu/video_player_view"
        const val CHANNEL = "klhu/video_player"

        /**
         * The view the page is watching, so the page's own `stop` reaches it
         * (the review is left, or the video being played is deleted). One page
         * plays one video, so one slot is the whole story.
         */
        @Volatile
        private var current: VideoPlayerView? = null

        /**
         * The page's own channel (`klhu/video_player`), registered once for the
         * engine and answered by whichever view is showing: the page has one
         * picture at a time, and a `stop` with nothing playing is a no-op.
         */
        fun register(messenger: BinaryMessenger) {
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                val view = current
                if (view == null) {
                    when (call.method) {
                        "position", "duration" -> result.success(0)
                        "play", "pause", "stop" -> result.success(null)
                        else -> result.notImplemented()
                    }
                } else {
                    view.onMethodCall(call, result)
                }
            }
        }
    }

    private val context: Context = context
    private val texture = TextureView(context)
    private var player: MediaPlayer? = null
    private var surface: Surface? = null
    private val controller = MediaController(context)

    /** The source, resolved once: a local file, or nothing to play at all. */
    private val source: String? =
        (creationParams as? Map<*, *>)?.get("source") as? String

    init {
        texture.surfaceTextureListener = this
        controller.setMediaPlayer(Controls())
        controller.setAnchorView(texture)
        // The platform's own bar appears on a tap of the picture, which is what
        // a `VideoView` did by itself; a `TextureView` answers touches instead.
        texture.setOnClickListener { toggleControls() }
        current = this
    }

    override fun getView(): View = texture

    // ---- the picture ------------------------------------------------------

    override fun onSurfaceTextureAvailable(
        texture: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        start()
    }

    override fun onSurfaceTextureSizeChanged(
        texture: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        fitPicture()
    }

    override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
        release()
        return true
    }

    override fun onSurfaceTextureUpdated(texture: SurfaceTexture) = Unit

    /**
     * Prepares the player once the texture has a surface, and starts it: a
     * player prepared without its surface is a picture nothing reaches.
     *
     * Rules 1 and 2: the source is a local file or a library uri, and a source
     * that will not resolve is simply not played — no spinner, no silence.
     */
    private fun start() {
        val file = source
        if (file.isNullOrEmpty() || !isLocal(file)) return
        val textureSurface = texture.surfaceTexture ?: return
        val surface = surface ?: Surface(textureSurface).also { this.surface = it }
        val player = player ?: runCatching {
            MediaPlayer().apply {
                if (file.startsWith("content:")) {
                    setDataSource(context, Uri.parse(file))
                } else {
                    setDataSource(stripFileScheme(file))
                }
                setSurface(surface)
                setOnVideoSizeChangedListener { _, width, height ->
                    // The picture keeps the video's own shape inside whatever
                    // box the page gives it: without this the frame is stretched
                    // to the box (a `VideoView` did the letterboxing itself).
                    fitPicture(width, height)
                }
                setOnErrorListener { _, _, _ ->
                    release()
                    true
                }
                setOnPreparedListener { prepared ->
                    fitPicture(prepared.videoWidth, prepared.videoHeight)
                    prepared.start()
                }
                prepareAsync()
            }
        }.getOrElse { return }
        this.player = player
    }

    /** Rule 4: leaving stops the player and releases it. */
    private fun release() {
        controller.hide()
        player?.let { playing ->
            runCatching {
                if (playing.isPlaying) playing.stop()
                playing.release()
            }
        }
        player = null
        surface?.release()
        surface = null
    }

    private fun toggleControls() {
        if (player == null) return
        if (controller.isShowing) controller.hide() else controller.show()
    }

    /**
     * Fits the video inside the view, keeping its own shape — centred, with the
     * page's background around it rather than a stretched picture.
     */
    private fun fitPicture(
        videoWidth: Int = player?.videoWidth ?: 0,
        videoHeight: Int = player?.videoHeight ?: 0,
    ) {
        if (videoWidth <= 0 || videoHeight <= 0) return
        val viewWidth = texture.width.toFloat()
        val viewHeight = texture.height.toFloat()
        if (viewWidth <= 0f || viewHeight <= 0f) return
        val scale = min(viewWidth / videoWidth, viewHeight / videoHeight)
        val matrix = Matrix()
        matrix.setScale(
            scale * videoWidth / viewWidth,
            scale * videoHeight / viewHeight,
        )
        matrix.postTranslate(
            (viewWidth - videoWidth * scale) / 2f,
            (viewHeight - videoHeight * scale) / 2f,
        )
        texture.setTransform(matrix)
    }

    // ---- the page's own methods -------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                player?.start()
                result.success(null)
            }

            "pause" -> {
                player?.pause()
                result.success(null)
            }

            "stop" -> {
                release()
                result.success(null)
            }

            // The view's own controls seek; these two are for showing where
            // playback is (the contract's method table).
            "position" -> result.success(
                player?.let { if (it.isPlaying) it.currentPosition else 0 } ?: 0,
            )

            "duration" -> result.success(player?.duration?.coerceAtLeast(0) ?: 0)

            else -> result.notImplemented()
        }
    }

    /** Rule 1: a local file or a local library uri, and nothing else. */
    private fun isLocal(source: String): Boolean {
        val parsed = Uri.parse(source)
        return when (parsed.scheme) {
            "content", "file" -> parsed.path?.isNotEmpty() == true
            null -> true
            else -> false
        }
    }

    private fun stripFileScheme(source: String): String =
        if (source.startsWith("file://")) Uri.parse(source).path.orEmpty() else source

    override fun dispose() {
        if (current === this) current = null
        release()
    }

    /** The platform's `MediaController`, driven by this view's player. */
    @Suppress("DEPRECATION")
    private inner class Controls : MediaController.MediaPlayerControl {
        override fun start() {
            player?.start()
        }

        override fun pause() {
            player?.pause()
        }

        override fun getDuration(): Int = player?.duration?.coerceAtLeast(0) ?: 0

        override fun getCurrentPosition(): Int = player?.currentPosition ?: 0

        override fun seekTo(position: Int) {
            player?.seekTo(position)
        }

        override fun isPlaying(): Boolean = player?.isPlaying == true

        // The picture is drawn as it is decoded from a local file: there is no
        // buffer to report and no place a seek cannot reach.
        override fun getBufferPercentage(): Int = 100

        override fun canPause(): Boolean = true

        override fun canSeekBackward(): Boolean = true

        override fun canSeekForward(): Boolean = true

        override fun getAudioSessionId(): Int = player?.audioSessionId ?: 0
    }
}

/** Creates the playback view for the engine, with the page's own source. */
class VideoPlayerViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        VideoPlayerView(context, messenger, viewId, args)
}
