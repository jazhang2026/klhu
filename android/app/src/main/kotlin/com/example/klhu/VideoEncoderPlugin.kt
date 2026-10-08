package com.example.klhu

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * The render's platform half (spec 012, contracts/video-frame-protocol.md and
 * video-file-protocol.md).
 *
 * Sink, not filter: it is handed pictures and audio files and answers with one
 * mp4. It knows nothing about text, sentences, languages, voices, or which
 * frame stands for how long — every decision that can be tested is taken in
 * Dart (research D4), and this file only encodes, muxes and writes.
 *
 * Two properties are load-bearing and are why the shape looks like this:
 *
 *  1. **The frames are the clock.** Each `sendFrame` carries the number of
 *     frames its picture stands for, and this side gives it exactly that many
 *     frames at `1e6 / fps` µs apart. The audio is padded or cut to the
 *     durations Dart measured, so the voice cannot drift from the picture
 *     (FR-016).
 *  2. **Nothing outside the working path is touched.** The library entry is
 *     US3's `keep`; a cancel or a failure deletes the working file here.
 *
 * Calls arrive one at a time (Dart awaits each) and each is answered only when
 * its work is done, so a single-thread executor is the whole concurrency story.
 */
class VideoEncoderPlugin : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "klhu/video_encoder"

        private const val MIME_VIDEO = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val MIME_AUDIO = MediaFormat.MIMETYPE_AUDIO_AAC

        /** How long a codec call may take before the render is declared stuck. */
        private const val TIMEOUT_US = 10_000L

        /** The audio encoder's target; the video's comes from Dart. */
        private const val AUDIO_BITRATE = 64_000

        /** One AAC input buffer's worth of PCM, in frames. */
        private const val AUDIO_CHUNK_FRAMES = 1024

        /**
         * How far either side of an output instant the resampler reads the
         * source, in source samples. The kernel's transition band is
         * `5.5 / (2 * RESAMPLE_HALF + 1)` cycles per sample — 2.0 kHz at 24 kHz
         * here, so with the cut-off 10 % under the source's own Nyquist the
         * whole transition sits below it and everything the source cannot hold
         * is in the stopband.
         */
        private const val RESAMPLE_HALF = 32

        private const val ACTION_IFRAME_SECONDS = 1
    }

    /** A failure the Dart side is told about, named by the frame contract's codes. */
    private class Failure(val code: String, message: String) : Exception(message)

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    // ---- the render in flight (all of it worker-thread state) ----------------

    private var video: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var videoTrack = -1
    private var audioTrack = -1
    private var muxerStarted = false
    private var workingPath: String? = null

    /** The audio is encoded whole at the start and kept until the muxer can take
     *  it: a track cannot be added after `MediaMuxer.start()`, and the muxer can
     *  only start once the video's own format is known. */
    private var audioFormat: MediaFormat? = null
    private var audioSamples: MutableList<Sample> = mutableListOf()
    private var audioUs = 0L

    private var frameIndex = 0L
    private var totalFrames = 0
    private var fps = 30
    private var frameWidth = 0
    private var frameHeight = 0
    private var videoMs = 0L

    private class Sample(val data: ByteArray, val timeUs: Long)

    private class Yuv(val y: ByteArray, val u: ByteArray, val v: ByteArray)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Every call is answered from the worker, never the platform thread:
        // converting a picture is tens of milliseconds, and that thread is the
        // one drawing the reader's own preview.
        worker.execute {
            try {
                val value = when (call.method) {
                    "isAvailable" -> hasEncoder()
                    "startRender" -> {
                        startRender(call)
                        null
                    }
                    "sendFrame" -> {
                        sendFrame(call)
                        null
                    }
                    "finishRender" -> finishRender()
                    "cancelRender" -> {
                        releaseAll(deleteWorkingFile = true)
                        null
                    }
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(value) }
            } catch (e: Failure) {
                fail(e.code)
                main.post { result.error(e.code, e.message, null) }
            } catch (e: Throwable) {
                fail("CODEC_FAILED")
                main.post { result.error("CODEC_FAILED", e.message ?: e.toString(), null) }
            }
        }
    }

    /** A render that failed or was cancelled leaves no file behind (FR-009). */
    private fun fail(code: String) {
        releaseAll(deleteWorkingFile = code != "CANCELLED")
    }

    // ---- the four calls ------------------------------------------------------

    private fun hasEncoder(): Boolean = try {
        MediaCodec.createEncoderByType(MIME_VIDEO).release()
        true
    } catch (e: Throwable) {
        false
    }

    private fun startRender(call: MethodCall) {
        // Whatever was there is replaced: a render that never finished must not
        // leak its codecs or its file.
        releaseAll(deleteWorkingFile = true)

        frameWidth = intArg(call, "frameWidth")
        frameHeight = intArg(call, "frameHeight")
        fps = intArg(call, "fps")
        val bitrate = intArg(call, "bitrateKbps") * 1000
        totalFrames = intArg(call, "totalFrames")
        val path = call.argument<String>("workingPath")
            ?: throw Failure("IO_FAILED", "no working path was given")
        frameIndex = 0
        videoMs = 0
        audioUs = 0

        File(path).parentFile?.mkdirs()
        workingPath = path

        try {
            video = MediaCodec.createEncoderByType(MIME_VIDEO).apply {
                configure(
                    MediaFormat.createVideoFormat(MIME_VIDEO, frameWidth, frameHeight).apply {
                        // The pictures arrive as pixels, so the input buffer is
                        // written directly (the `Image` route in `sendFrame`)
                        // rather than through a GL context.
                        setInteger(
                            MediaFormat.KEY_COLOR_FORMAT,
                            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
                        )
                        setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                        setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                        setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, ACTION_IFRAME_SECONDS)
                    },
                    null,
                    null,
                    MediaCodec.CONFIGURE_FLAG_ENCODE,
                )
                start()
            }
            muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        } catch (e: Throwable) {
            throw Failure("CODEC_FAILED", "this device refused to start a render: ${e.message}")
        }

        // The whole audio, in timeline order. Silence (`path: null`) is the
        // title card and the hold — it is part of the timeline and is muxed.
        encodeAudio(call)
    }

    private fun intArg(call: MethodCall, name: String): Int =
        (call.argument<Any?>(name) as? Number)?.toInt()
            ?: throw Failure("IO_FAILED", "$name is missing")

    private fun sendFrame(call: MethodCall) {
        val codec = video ?: throw Failure("CODEC_FAILED", "no render is running")
        val repeat = intArg(call, "repeat")
        if (repeat < 1) throw Failure("CODEC_FAILED", "a picture stood for $repeat frames")
        val bytes = call.argument<ByteArray>("bytes")
            ?: throw Failure("CODEC_FAILED", "a frame arrived with no picture")

        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw Failure("CODEC_FAILED", "a frame's picture could not be decoded")
        if (bitmap.width != frameWidth || bitmap.height != frameHeight) {
            // The plan's size is what the codec was configured with; a picture
            // of another size would be a different video.
            throw Failure(
                "CODEC_FAILED",
                "a frame is ${bitmap.width}x${bitmap.height}, not ${frameWidth}x$frameHeight",
            )
        }

        // Converted once per *picture*, and every call carries its own: a
        // picture cached across calls would write the first one for the whole
        // render (the contract forbids coalescing frames).
        val yuv = rgbToYuv(bitmap)
        bitmap.recycle()

        for (i in 0 until repeat) {
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index < 0) throw Failure("CODEC_FAILED", "the encoder stopped taking frames")
            val image = codec.getInputImage(index)
                ?: throw Failure(
                    "CODEC_FAILED",
                    "this device's encoder offers no writable frame buffer",
                )
            fillImage(image, yuv)
            codec.queueInputBuffer(index, 0, inputSize(image), frameIndex * 1_000_000L / fps, 0)
            frameIndex++
            drainVideo()
        }
        videoMs = frameIndex * 1000L / fps
    }

    private fun finishRender(): Map<String, Any?> {
        val codec = video ?: throw Failure("CODEC_FAILED", "no render is running")
        if (frameIndex != totalFrames.toLong()) {
            // The picture must not drift from the voice: a file that is not the
            // length the timeline promised is a broken video, not a short one.
            throw Failure(
                "CODEC_FAILED",
                "the render promised $totalFrames frames and got $frameIndex",
            )
        }
        try {
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index >= 0) {
                codec.queueInputBuffer(
                    index,
                    0,
                    0,
                    frameIndex * 1_000_000L / fps,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                )
            }
            while (!drainVideo()) {
                // Drain to the end of the stream: a file that is not closed is
                // not a file.
            }
            val path = workingPath ?: throw Failure("IO_FAILED", "no working file")
            // Read the two clocks before the teardown clears them.
            val durationMs = maxOf(videoMs, audioUs / 1000)
            releaseAll(deleteWorkingFile = false)
            return mapOf(
                "path" to path,
                "durationMs" to durationMs,
                "sizeBytes" to File(path).length(),
            )
        } catch (e: Failure) {
            throw e
        } catch (e: Throwable) {
            throw Failure("CODEC_FAILED", "the file could not be closed: ${e.message}")
        }
    }

    // ---- video ---------------------------------------------------------------

    /**
     * Writes [picture] into the encoder's own input buffer.
     *
     * The buffer's layout is the encoder's to choose (row and pixel strides,
     * planar or semi-planar chroma), so every copy below goes through the
     * plane's own strides instead of assuming a layout. Only the frame's own
     * top-left region is filled: an aligned buffer can be larger than the frame.
     */
    private fun fillImage(image: Image, picture: Yuv) {
        val planes = image.planes
        copyPlane(planes[0], picture.y, frameWidth, frameHeight, frameWidth, 1)
        copyPlane(planes[1], picture.u, frameWidth / 2, frameHeight / 2, frameWidth / 2, 2)
        copyPlane(planes[2], picture.v, frameWidth / 2, frameHeight / 2, frameWidth / 2, 2)
    }

    private fun copyPlane(
        plane: Image.Plane,
        src: ByteArray,
        width: Int,
        height: Int,
        srcRowStride: Int,
        step: Int,
    ) {
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val capacity = buffer.capacity()
        if (step == 1 && pixelStride == 1) {
            for (row in 0 until height) {
                val offset = row * rowStride
                if (offset >= capacity) break
                buffer.position(offset)
                buffer.put(src, row * srcRowStride, minOf(width, buffer.remaining()))
            }
            return
        }
        // Chroma, and the semi-planar case: one byte per sample, [pixelStride]
        // apart (so a stride of 2 interleaves U and V in one plane).
        for (row in 0 until height) {
            val rowOffset = row * rowStride
            if (rowOffset >= capacity) break
            for (column in 0 until width) {
                val offset = rowOffset + column * pixelStride
                if (offset >= capacity) break
                buffer.put(offset, src[row * srcRowStride + column])
            }
        }
    }

    /** The whole YUV frame, which is what the codec's own buffer holds. */
    private fun inputSize(image: Image): Int {
        val plane = image.planes[0]
        return plane.rowStride * image.height * 3 / 2
    }

    /** BT.601 limited-range YUV 4:2:0, the layout an SDR H.264 player expects. */
    private fun rgbToYuv(bitmap: Bitmap): Yuv {
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val y = ByteArray(width * height)
        val u = ByteArray(width * height / 4)
        val v = ByteArray(width * height / 4)
        var luma = 0
        var chroma = 0
        for (row in 0 until height) {
            for (column in 0 until width) {
                val colour = pixels[row * width + column]
                val r = (colour shr 16) and 0xFF
                val g = (colour shr 8) and 0xFF
                val b = colour and 0xFF
                y[luma++] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte()
                if (row % 2 == 0 && column % 2 == 0) {
                    u[chroma] = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte()
                    v[chroma] = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte()
                    chroma++
                }
            }
        }
        return Yuv(y, u, v)
    }

    /** Writes what the encoder has produced. Answers whether the stream ended. */
    private fun drainVideo(): Boolean {
        val codec = video ?: return true
        val info = MediaCodec.BufferInfo()
        while (true) {
            val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> return false
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> onVideoFormat(codec.outputFormat)
                index >= 0 -> {
                    val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (!isConfig && info.size > 0) {
                        if (!muxerStarted) {
                            throw Failure("CODEC_FAILED", "a frame arrived before the file was open")
                        }
                        val buffer = codec.getOutputBuffer(index)
                            ?: throw Failure("CODEC_FAILED", "the encoder handed back no frame")
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer?.writeSampleData(videoTrack, buffer, info)
                    }
                    val ended = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    codec.releaseOutputBuffer(index, false)
                    if (ended) return true
                }
                else -> return false
            }
        }
    }

    /**
     * The video's own format is what opens the file: both tracks are added, the
     * muxer starts, and the audio encoded at the start is written into its track
     * now — samples per track must be in order, and the audio was built in
     * timeline order.
     */
    private fun onVideoFormat(format: MediaFormat) {
        val mux = muxer ?: throw Failure("CODEC_FAILED", "no file to write")
        val audio = audioFormat ?: throw Failure("CODEC_FAILED", "no audio was prepared")
        videoTrack = mux.addTrack(format)
        audioTrack = mux.addTrack(audio)
        mux.start()
        muxerStarted = true
        for (sample in audioSamples) {
            val info = MediaCodec.BufferInfo().apply { set(0, sample.data.size, sample.timeUs, 0) }
            mux.writeSampleData(audioTrack, ByteBuffer.wrap(sample.data), info)
        }
        audioSamples = mutableListOf()
    }

    // ---- audio ---------------------------------------------------------------

    /**
     * Reads every segment's WAV, makes it exactly as long as its slot, and
     * encodes the lot to AAC, keeping the samples until the muxer can take them.
     *
     * A WAV shorter than its slot is padded with silence and a longer one is
     * cut: the slot lengths are what the frames were planned against (FR-016), so
     * the audio is made to fit the picture and never the other way round.
     *
     * One rate for the whole stream: the highest the sentences carry, so no
     * sentence is resampled down. The engine writes the on-device copy of a voice
     * at 24 kHz and its network copy at 48 kHz, and one read may use both — the
     * picker offers one copy per voice (2026-10-06) but a voice the device has
     * not installed comes as its network copy, and a pick stored before then is
     * still a network one, so a read may still mix them. The muxer takes one
     * rate, so the 24 kHz sentences are converted up rather than refused
     * (measured on the OnePlus 13: a dialogue whose narration read through a
     * `-local` voice and whose roles read through `-network` ones came out as
     * twelve sentences at 48 kHz and one at 24 kHz, and the render failed).
     * The conversion is [resample]'s; it must be band-limited, which is what the
     * first version of this was not.
     * Two different channel counts stay a failure: that is not a rate to convert
     * but two layouts the muxer cannot hold.
     */
    private fun encodeAudio(call: MethodCall) {
        val raw = call.argument<Any?>("audioSegments") as? List<*> ?: emptyList<Any?>()
        val segments = mutableListOf<Segment>()
        var rate = 0
        var channels = 0
        for (entry in raw) {
            val map = entry as? Map<*, *> ?: continue
            val durationUs = (map["durationUs"] as? Number)?.toLong() ?: 0L
            val path = map["path"] as? String
            val read = if (path == null) null else readWav(File(path))
            if (read != null) {
                if (channels == 0) {
                    channels = read.channels
                } else if (read.channels != channels) {
                    throw Failure(
                        "IO_FAILED",
                        "the sentences were written in different audio layouts; they cannot be muxed",
                    )
                }
                if (read.rate > rate) rate = read.rate
            }
            segments.add(Segment(durationUs, read))
        }
        if (rate == 0) {
            // Every slot was silence. The codec still needs a format, so it gets
            // the engine's own.
            rate = 24_000
            channels = 1
        }
        for (segment in segments) {
            val pcm = segment.pcm ?: continue
            if (pcm.rate != rate) {
                segment.pcm =
                    Pcm(rate, pcm.channels, resample(pcm.data, pcm.rate, rate))
            }
        }

        val codec = try {
            MediaCodec.createEncoderByType(MIME_AUDIO).apply {
                configure(
                    MediaFormat.createAudioFormat(MIME_AUDIO, rate, channels).apply {
                        setInteger(
                            MediaFormat.KEY_AAC_PROFILE,
                            MediaCodecInfo.CodecProfileLevel.AACObjectLC,
                        )
                        setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BITRATE)
                        setInteger(
                            MediaFormat.KEY_MAX_INPUT_SIZE,
                            AUDIO_CHUNK_FRAMES * 2 * channels,
                        )
                    },
                    null,
                    null,
                    MediaCodec.CONFIGURE_FLAG_ENCODE,
                )
                start()
            }
        } catch (e: Throwable) {
            throw Failure("CODEC_FAILED", "this device refused to encode audio: ${e.message}")
        }

        try {
            val blockAlign = 2 * channels
            var timeUs = 0L
            for (segment in segments) {
                val wanted = (segment.durationUs * rate / 1_000_000L * blockAlign).toInt()
                val source = segment.pcm?.data
                val used = if (source == null) 0 else minOf(source.size, wanted)
                if (source != null && used > 0) {
                    timeUs = feed(codec, source, used, blockAlign, rate, timeUs)
                }
                if (used < wanted) {
                    val silence = ByteArray(wanted - used)
                    timeUs = feed(codec, silence, silence.size, blockAlign, rate, timeUs)
                }
            }
            audioUs = timeUs
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index >= 0) {
                codec.queueInputBuffer(index, 0, 0, timeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            }
            drainAudio(codec, true)
        } finally {
            try {
                codec.stop()
            } catch (e: Throwable) {
                // The render is reporting its own failure; releasing is enough.
            }
            codec.release()
        }
    }

    private class Segment(val durationUs: Long, var pcm: Pcm?)

    private class Pcm(val rate: Int, val channels: Int, val data: ByteArray)

    /**
     * Resamples 16-bit PCM from [from] Hz to [to] Hz with a windowed-sinc
     * interpolator: each output sample is the source evaluated at that instant
     * through a Blackman-windowed sinc, so the samples that fall between the
     * source's own samples are reconstructed instead of drawn along the line
     * between them.
     *
     * Linear interpolation is what this replaced (2026-10-06, heard on the
     * OnePlus 13 as a hiss over the first sentence of a dialogue video). It does
     * not reconstruct anything: it leaves a mirror of the voice's top octave
     * above the source's own Nyquist. Measured on a real engine sentence
     * (`s1_zh-picked.wav`, 24 kHz, written up at 48 kHz), linear interpolation
     * puts 12–16 kHz at −75 dBFS, where a band-limited conversion of the same
     * sentence leaves −121 dBFS and the source itself cannot hold anything at
     * all. That artefact survives the AAC encoder; a listener hears it as hiss,
     * and the 24 kHz narration slot of `周末公园散步` came out 25 dB brighter
     * above 10 kHz than the twelve 48 kHz sentences around it.
     *
     * The kernel is truncated to [RESAMPLE_HALF] source samples a side, giving
     * a 2 kHz transition band on a 24 kHz source, and its cut-off sits 10 % under
     * that source's Nyquist, so the whole transition is below the point where an
     * artefact may start. Measured on the same sentence written up at 48 kHz:
     * −121 dBFS in 12–16 kHz, against −75 dBFS for the linear interpolation this
     * replaced and −121 dBFS for ffmpeg's own `soxr` converter. Taps are
     * normalised so the conversion cannot shift the level, and the sum is
     * clamped, because a transient at the edge of the window can overshoot the
     * 16-bit range.
     */
    private fun resample(data: ByteArray, from: Int, to: Int): ByteArray {
        if (from == to || from <= 0 || to <= 0) return data
        val samples = data.size / 2
        if (samples < 2) return data
        val out = ByteArray((samples.toLong() * to / from).toInt() * 2)
        val step = from.toDouble() / to
        // A cut-off 10 % under the source's own Nyquist: what linear
        // interpolation left behind is a mirror of the voice's top octave that
        // STARTS at that Nyquist, so a filter still rolling off there would keep
        // its first kilohertz. The voice holds nothing up there (measured: peak
        // −89 dBFS in 11–12 kHz on a real engine sentence), so this gives up no
        // audible sound. The min() keeps a conversion asked for the other way
        // round from folding the top band down instead of cutting it.
        val omega = minOf(0.9, 0.9 * to / from)
        for (i in 0 until out.size / 2) {
            val at = i * step
            val base = floor(at).toInt()
            val frac = at - base
            var sum = 0.0
            var gain = 0.0
            for (j in -RESAMPLE_HALF + 1..RESAMPLE_HALF) {
                val index = base + j
                if (index < 0 || index >= samples) continue
                val t = frac - j
                val tap = omega * sinc(omega * t) * blackman(t)
                sum += tap * readSample(data, index)
                gain += tap
            }
            val value = if (gain == 0.0) 0 else (sum / gain).roundToInt()
            writeSample(out, i, value.coerceIn(-32768, 32767))
        }
        return out
    }

    /** sin(πt)/πt, 1 at zero. */
    private fun sinc(t: Double): Double {
        if (t == 0.0) return 1.0
        val x = PI * t
        return sin(x) / x
    }

    /** Blackman window over ±[RESAMPLE_HALF] source samples, zero at the ends. */
    private fun blackman(t: Double): Double {
        if (abs(t) > RESAMPLE_HALF) return 0.0
        val x = PI * t / RESAMPLE_HALF
        return 0.42 + 0.5 * cos(x) + 0.08 * cos(2 * x)
    }

    /** One 16-bit little-endian sample, sign extended. */
    private fun readSample(data: ByteArray, index: Int): Int =
        (data[index * 2].toInt() and 0xFF) or (data[index * 2 + 1].toInt() shl 8)

    /** Writes one 16-bit little-endian sample. */
    private fun writeSample(out: ByteArray, index: Int, value: Int) {
        out[index * 2] = (value and 0xFF).toByte()
        out[index * 2 + 1] = ((value shr 8) and 0xFF).toByte()
    }

    /** Feeds [size] bytes from [bytes] and answers the time after them. */
    private fun feed(
        codec: MediaCodec,
        bytes: ByteArray,
        size: Int,
        blockAlign: Int,
        rate: Int,
        fromUs: Long,
    ): Long {
        var offset = 0
        var timeUs = fromUs
        while (offset < size) {
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index < 0) throw Failure("CODEC_FAILED", "the audio encoder stopped taking sound")
            val chunk = minOf(AUDIO_CHUNK_FRAMES * blockAlign, size - offset)
            val buffer = codec.getInputBuffer(index)
                ?: throw Failure("CODEC_FAILED", "the audio encoder handed back no buffer")
            buffer.clear()
            buffer.put(bytes, offset, chunk)
            codec.queueInputBuffer(index, 0, chunk, timeUs, 0)
            offset += chunk
            timeUs += chunk.toLong() / blockAlign * 1_000_000L / rate
            drainAudio(codec, false)
        }
        return timeUs
    }

    /** Keeps every encoded sample, and remembers the track's own format. */
    private fun drainAudio(codec: MediaCodec, blocking: Boolean) {
        val info = MediaCodec.BufferInfo()
        while (true) {
            val index = codec.dequeueOutputBuffer(info, if (blocking) TIMEOUT_US else 0)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> return
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> audioFormat = codec.outputFormat
                index >= 0 -> {
                    val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (!isConfig && info.size > 0) {
                        val buffer = codec.getOutputBuffer(index)
                        if (buffer != null) {
                            val data = ByteArray(info.size)
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            buffer.get(data)
                            audioSamples.add(Sample(data, info.presentationTimeUs))
                        }
                    }
                    val ended = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    codec.releaseOutputBuffer(index, false)
                    if (ended) return
                }
                else -> return
            }
        }
    }

    /** Reads a RIFF/WAVE file's PCM, whatever its chunk order or padding. */
    private fun readWav(file: File): Pcm {
        if (!file.exists()) throw Failure("IO_FAILED", "a sentence's audio is missing")
        val bytes = file.readBytes()
        if (bytes.size < 44 || String(bytes, 0, 4) != "RIFF" || String(bytes, 8, 4) != "WAVE") {
            throw Failure("IO_FAILED", "a sentence's audio is not a RIFF/WAVE file")
        }
        val little = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var rate = 0
        var channels = 0
        var bits = 0
        var format = 0
        var dataAt = -1
        var dataSize = 0
        var at = 12
        while (at + 8 <= bytes.size) {
            val id = String(bytes, at, 4)
            val size = little.getInt(at + 4)
            val body = at + 8
            when (id) {
                "fmt " -> {
                    format = little.getShort(body).toInt()
                    channels = little.getShort(body + 2).toInt()
                    rate = little.getInt(body + 4)
                    bits = little.getShort(body + 14).toInt()
                }
                "data" -> {
                    dataAt = body
                    dataSize = minOf(size, bytes.size - body)
                }
            }
            if (size <= 0) break
            at = body + size + (size and 1)
        }
        if (format != 1 || bits != 16 || rate <= 0 || channels <= 0 || dataAt < 0) {
            throw Failure("IO_FAILED", "a sentence's audio is not 16-bit PCM")
        }
        return Pcm(rate, channels, bytes.copyOfRange(dataAt, dataAt + dataSize))
    }

    // ---- teardown ------------------------------------------------------------

    /**
     * Closes everything the render holds and deletes its file when the caller
     * says so. Safe at any point, including before a render has started.
     */
    private fun releaseAll(deleteWorkingFile: Boolean) {
        val codec = video
        video = null
        if (codec != null) {
            try {
                codec.stop()
            } catch (e: Throwable) {
                // Already stopped or already failing: releasing is what matters.
            }
            codec.release()
        }
        if (muxerStarted) {
            try {
                muxer?.stop()
            } catch (e: Throwable) {
                // A muxer that cannot stop is not something the reader can act
                // on; the file is deleted right below either way.
            }
        }
        try {
            muxer?.release()
        } catch (e: Throwable) {
            // Same.
        }
        muxer = null
        muxerStarted = false
        videoTrack = -1
        audioTrack = -1
        audioFormat = null
        audioSamples = mutableListOf()
        audioUs = 0
        frameIndex = 0
        totalFrames = 0
        videoMs = 0
        workingPath?.let { path -> if (deleteWorkingFile) File(path).delete() }
        workingPath = null
    }
}
