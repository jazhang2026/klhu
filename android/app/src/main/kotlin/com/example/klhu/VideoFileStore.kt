package com.example.klhu

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

/**
 * Where a video lives once the reader keeps it (spec 012 US3,
 * contracts/video-file-protocol.md).
 *
 * Keeping is the only call that writes into the device's video library, and it
 * is the only thing the app ever puts there: cancelling, failing or throwing a
 * render away writes nothing (FR-009/FR-021). The working copy the render made
 * stays where it is — it is what the review plays — and this file either
 * promotes it into the library or leaves it alone.
 *
 * Two properties are load-bearing:
 *
 *  1. **Write, then delete.** A replacement (`previousUri`) is removed only
 *     after the new file is in place, so a failed keep never leaves the reader
 *     with nothing (FR-012).
 *  2. **Nothing but a local file is ever handed anywhere.** A share is the
 *     phone's own list with a local uri; a kept video is shared by its library
 *     uri, a working copy through this app's `FileProvider` (D13). No upload,
 *     no account, no network (FR-023).
 *
 * The API split is Android's, not a preference: from API 29 the library is
 * written through `MediaStore` (an entry published by clearing `IS_PENDING`);
 * before that, into the public Movies directory, announced to the gallery with
 * a media scan (D7).
 */
class VideoFileStore private constructor(
    private val context: Context,
    private val activity: Activity?,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "klhu/video_files"

        /** The folder the phone's gallery shows, inside Movies. */
        private const val ALBUM = "Klhu"

        private const val MIME_VIDEO = "video/mp4"

        /** How long the media scan is given to answer with the library's uri. */
        private const val SCAN_TIMEOUT_SECONDS = 5L

        fun register(messenger: BinaryMessenger, context: Context, activity: Activity?) {
            MethodChannel(messenger, CHANNEL)
                .setMethodCallHandler(VideoFileStore(context.applicationContext, activity))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAvailable" -> result.success(true)

                "keep" -> result.success(
                    keep(
                        workingPath = call.argument<String>("workingPath").orEmpty(),
                        displayName = call.argument<String>("displayName").orEmpty(),
                        previousUri = call.argument<String>("previousUri"),
                    )
                )

                "share" -> {
                    share(call.argument<String>("source").orEmpty())
                    result.success(null)
                }

                "delete" -> result.success(delete(call.argument<String>("uri").orEmpty()))

                "exists" -> result.success(exists(call.argument<String>("uri").orEmpty()))

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Named by the frame contract's own code, so a failure in the field
            // says which one it was (the page shows the reader the message).
            result.error("IO_FAILED", e.message ?: "the file store refused", null)
        }
    }

    /** Promotes the working copy into the library under `displayName` (FR-011). */
    private fun keep(workingPath: String, displayName: String, previousUri: String?): Map<String, Any?> {
        val source = File(workingPath)
        if (!source.isFile) throw IOException("no working copy at $workingPath")
        val name = libraryName(displayName)

        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            keepInLibrary(source, name)
        } else {
            keepInMovies(source, name)
        }

        // FR-012: the new file is in place before the old one goes, so a failure
        // above leaves what the reader already had.
        if (!previousUri.isNullOrEmpty() && previousUri != uri.toString()) {
            delete(previousUri)
        }
        return mapOf("uri" to uri.toString(), "name" to name)
    }

    /**
     * The name the library entry is made under. Dart names it (the content's own
     * name and the extension); this only guarantees that a name is a name — a
     * content called `A/B` must not write into a subdirectory on the branch that
     * builds a path out of it.
     */
    private fun libraryName(displayName: String): String {
        val cleaned = displayName
            .map { if (it == '/' || it == '\\' || it.code == 0) '-' else it }
            .joinToString("")
            .trim()
        return cleaned.ifEmpty { "klhu video.mp4" }
    }

    /** API 29+: an insert into Movies/Klhu, published when the bytes are there. */
    private fun keepInLibrary(source: File, name: String): Uri {
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, name)
            put(MediaStore.Video.Media.MIME_TYPE, MIME_VIDEO)
            put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/$ALBUM")
            // Pending until the bytes are complete: a half-written video never
            // appears in anyone's gallery.
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val target = context.contentResolver.insert(collection, values)
            ?: throw IOException("the library refused the entry")
        try {
            val out = context.contentResolver.openOutputStream(target)
                ?: throw IOException("the library refused the bytes")
            out.use { sink -> FileInputStream(source).use { it.copyTo(sink) } }
        } catch (e: Exception) {
            context.contentResolver.delete(target, null, null)
            throw e
        }
        val published = ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }
        context.contentResolver.update(target, published, null, null)
        return target
    }

    /** API 24-28: the public Movies directory, announced by a media scan (D7). */
    private fun keepInMovies(source: File, name: String): Uri {
        if (!hasLegacyWritePermission()) {
            // The library below API 29 is a directory, so it needs the old
            // storage permission. Asking here means the reader's second tap
            // works; the first one says why not (the message is the reader's).
            activity?.let {
                ActivityCompat.requestPermissions(
                    it,
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    REQUEST_WRITE,
                )
            }
            throw IOException(
                "the storage permission is needed to keep a video on this device"
            )
        }
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), ALBUM)
        if (!dir.isDirectory && !dir.mkdirs()) throw IOException("could not make ${dir.path}")
        val target = File(dir, name)
        source.copyTo(target, overwrite = true)

        // The scan is what gives the gallery its entry, and it answers with the
        // library's own uri — which is what the record keeps, so sharing,
        // deleting and checking all speak one language across API levels.
        val scanned = CompletableFuture<Uri?>()
        MediaScannerConnection.scanFile(context, arrayOf(target.path), arrayOf(MIME_VIDEO)) { _, uri ->
            scanned.complete(uri)
        }
        return try {
            scanned.get(SCAN_TIMEOUT_SECONDS, TimeUnit.SECONDS) ?: Uri.fromFile(target)
        } catch (e: Exception) {
            // A gallery that never answered is not a failed keep: the file is
            // there, so the reader is told where it is rather than nothing.
            Uri.fromFile(target)
        }
    }

    private fun hasLegacyWritePermission(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) == PackageManager.PERMISSION_GRANTED

    /** Hands the file to the phone's own share list and returns (D13). */
    private fun share(source: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = MIME_VIDEO
            putExtra(Intent.EXTRA_STREAM, uriOf(source))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        // Started from the application's own context: a chooser is its own task.
        context.startActivity(
            Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    /** A local path or a local library uri; anything else is refused (FR-013). */
    private fun uriOf(source: String): Uri {
        val parsed = Uri.parse(source)
        return when (parsed.scheme) {
            // A kept video: the library's own uri needs no provider.
            "content" -> parsed

            // A working copy: this app's provider, because a `file://` uri
            // handed to another app is a `FileUriExposedException` (D11).
            null, "file" -> {
                val file = File(if (parsed.scheme == null) source else parsed.path.orEmpty())
                if (!file.isFile) throw IOException("no file at ${file.path}")
                FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    file,
                )
            }

            else -> throw IOException("not a local file: $source")
        }
    }

    /** Removes the file from the library. True also when it was already gone. */
    private fun delete(uri: String): Boolean {
        val parsed = Uri.parse(uri)
        if (parsed.scheme == "content") {
            try {
                context.contentResolver.delete(parsed, null, null)
            } catch (e: Exception) {
                // Falling through to the check: the answer is whether it is gone,
                // not whether this call is what removed it.
            }
            return !exists(uri)
        }
        val file = File(parsed.path ?: uri)
        return !file.exists() || file.delete()
    }

    /** Whether a video the record names is still in the library (FR-022). */
    private fun exists(uri: String): Boolean {
        val parsed = Uri.parse(uri)
        if (parsed.scheme == "content") {
            return try {
                context.contentResolver.openFileDescriptor(parsed, "r")?.use { true } ?: false
            } catch (e: Exception) {
                false
            }
        }
        return File(parsed.path ?: uri).isFile
    }
}

/** The request code the legacy storage permission is asked under. */
private const val REQUEST_WRITE = 71
