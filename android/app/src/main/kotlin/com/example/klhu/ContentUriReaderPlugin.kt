package com.example.klhu

import android.content.ContentResolver
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * The content:// URI reader (spec 026).
 *
 * When `file_selector` returns a `content://` URI for a Google Drive file,
 * `XFile.readAsBytes()` may return empty on some Android versions. This plugin
 * reads the URI through the platform's ContentResolver, so Drive files flow
 * through the existing extraction seam unchanged.
 *
 * Method channel: `klhu/document_picker`
 * Method: `readContentUri` — argument `uri` (String), returns `List<int>` bytes.
 */
class ContentUriReaderPlugin : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "klhu/document_picker"
    }

    private lateinit var resolver: ContentResolver

    fun register(messenger: BinaryMessenger, resolver: ContentResolver) {
        this.resolver = resolver
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readContentUri" -> {
                val uriString = call.argument<String>("uri")
                    ?: run { result.error("INVALID_URI", "no uri argument", null); return }
                val uri = Uri.parse(uriString)
                if (uri.scheme != ContentResolver.SCHEME_CONTENT) {
                    result.error(
                        "NOT_CONTENT_URI",
                        "expected content:// but got ${uri.scheme}",
                        null,
                    )
                    return
                }
                try {
                    val stream = resolver.openInputStream(uri)
                        ?: run { result.error("STREAM_FAILED", "openInputStream returned null", null); return }
                    val buffer = ByteArrayOutputStream()
                    stream.use { it.copyTo(buffer) }
                    result.success(buffer.toByteArray())
                } catch (e: Exception) {
                    result.error("READ_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
