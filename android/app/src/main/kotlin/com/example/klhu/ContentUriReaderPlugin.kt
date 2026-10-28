package com.example.klhu

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * The content:// URI reader and Google Drive file exporter (spec 026).
 *
 * Two capabilities:
 *
 *  1. **readContentUri** — reads bytes from any `content://` URI through the
 *     platform's ContentResolver. For local content providers this works
 *     directly. For Google Drive files (DocListProvider is not exported),
 *     falls back to opening the file in Google Drive app for export.
 *
 *  2. **exportDriveFile** — triggers a Google Drive export via ACTION_VIEW
 *     intent when direct read fails.
 *
 * Method channel: `klhu/document_picker`
 * Methods:
 *   - `readContentUri` — argument `uri` (String), returns `List<int>` bytes
 *     on success, or error code on failure.
 *   - `exportDriveFile` — argument `uri` (String), returns `Map<String, Any>`
 *     with `uri` and `message` keys.
 */
class ContentUriReaderPlugin : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "klhu/document_picker"
        // Google Drive content provider authority
        private const val DRIVE_STORAGE_AUTHORITY = "com.google.android.apps.docs.storage"
        private const val DRIVE_PHOTO_AUTHORITY = "com.google.android.apps.photoscontent"
    }

    private lateinit var resolver: ContentResolver
    private var activity: Activity? = null

    fun register(messenger: BinaryMessenger, resolver: ContentResolver, activity: Activity) {
        this.resolver = resolver
        this.activity = activity
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readContentUri" -> readContentUri(call, result)
            "exportDriveFile" -> exportDriveFile(call, result)
            else -> result.notImplemented()
        }
    }

    // --------------------------------------------------------------------
    // readContentUri: read any content:// URI through ContentResolver
    // --------------------------------------------------------------------

    private fun readContentUri(call: MethodCall, result: MethodChannel.Result) {
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

        // Google Drive files: DocListProvider is not exported to third-party apps.
        // Try direct read first; if it fails, open in Drive for export.
        if (isDriveUri(uri)) {
            try {
                val stream = resolver.openInputStream(uri)
                    ?: run { throw Exception("openInputStream returned null") }
                val buffer = ByteArrayOutputStream()
                stream.use { it.copyTo(buffer) }
                if (buffer.size() > 0) {
                    result.success(buffer.toByteArray())
                    return
                }
            } catch (e: SecurityException) {
                // Expected for DocListProvider — fall through to export
            } catch (e: Exception) {
                // Other read failures — fall through to export
            }
            // Direct read failed — trigger Drive export
            exportAndNotify(result, uriString)
            return
        }

        // Non-Drive content URI — read directly
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

    // --------------------------------------------------------------------
    // exportDriveFile: trigger Google Drive export via ACTION_VIEW intent
    // --------------------------------------------------------------------

    private fun isDriveUri(uri: Uri): Boolean {
        val auth = uri.authority ?: return false
        return auth.contains(DRIVE_STORAGE_AUTHORITY) ||
                auth.contains(DRIVE_PHOTO_AUTHORITY)
    }

    private fun exportAndNotify(result: MethodChannel.Result, uriString: String) {
        val act = activity
            ?: run { result.error("NO_ACTIVITY", "activity not available", null); return }
        val uri = Uri.parse(uriString)
        try {
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            act.startActivity(intent)
            result.success(mapOf(
                "uri" to uriString,
                "message" to "请从 Google Drive 中导出此文件（分享 → 保存到设备），然后重新选择。",
            ))
        } catch (e: ActivityNotFoundException) {
            result.error("NO_DRIVE_APP", "Google Drive is not installed", null)
        } catch (e: Exception) {
            result.error("EXPORT_FAILED", e.message, null)
        }
    }

    /**
     * Triggers a Google Drive export for the given content URI.
     * Opens the file in Google Drive app where the user can export it.
     */
    private fun exportDriveFile(call: MethodCall, result: MethodChannel.Result) {
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
        exportAndNotify(result, uriString)
    }
}
