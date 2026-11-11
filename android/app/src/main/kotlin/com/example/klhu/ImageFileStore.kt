package com.example.klhu

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream

/**
 * Saves AI-generated images into the device's public Pictures/Klhu album so
 * they are immediately visible in the Gallery app and file manager.
 *
 * On API 29+ uses MediaStore (no permission needed).
 * On API 24-28 writes to the public Pictures directory and runs a media scan.
 */
class ImageFileStore private constructor(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "klhu/image_files"

        private const val ALBUM = "Klhu"
        private const val MIME_JPEG = "image/jpeg"
        private const val MIME_PNG = "image/png"

        fun register(messenger: BinaryMessenger, context: Context) {
            MethodChannel(messenger, CHANNEL)
                .setMethodCallHandler(ImageFileStore(context.applicationContext))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "save" -> {
                    val bytesList = call.argument<List<Int>>("bytes") ?: run {
                        result.error("INVALID_ARGS", "bytes argument is required", null)
                        return
                    }
                    val bytes = ByteArray(bytesList.size)
                    for (i in bytesList.indices) bytes[i] = bytesList[i].toByte()
                    val mimeType = call.argument<String>("mimeType") ?: MIME_JPEG
                    val baseName = call.argument<String>("baseName") ?: "AI_image"
                    val uri = saveImage(bytes, mimeType, baseName)
                    result.success(mapOf("uri" to uri.toString(), "path" to uri.path))
                }

                // Overwrites the existing Klhu-album file with the same
                // display name, or inserts a new one — keeps exactly one
                // persisted file per scene prompt.
                "upsert" -> {
                    val bytesList = call.argument<List<Int>>("bytes") ?: run {
                        result.error("INVALID_ARGS", "bytes argument is required", null)
                        return
                    }
                    val bytes = ByteArray(bytesList.size)
                    for (i in bytesList.indices) bytes[i] = bytesList[i].toByte()
                    val mimeType = call.argument<String>("mimeType") ?: MIME_JPEG
                    val baseName = call.argument<String>("baseName") ?: "AI_image"
                    val uri = upsertImage(bytes, mimeType, baseName)
                    result.success(mapOf("uri" to uri.toString(), "path" to uri.path))
                }

                "delete" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr == null) {
                        result.error("INVALID_ARGS", "uri argument is required", null)
                        return
                    }
                    result.success(mapOf("deleted" to deleteImage(Uri.parse(uriStr))))
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("IO_FAILED", e.message ?: "image save failed", null)
        }
    }

    /**
     * Saves [bytes] as a JPEG/PNG into the public Pictures/Klhu album.
     * Returns the MediaStore content URI (or file:// on legacy devices).
     */
    fun saveImage(bytes: ByteArray, mimeType: String, baseName: String): Uri {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveToMediaStore(bytes, mimeType, baseName)
        } else {
            saveToPublicDirectory(bytes, mimeType, baseName)
        }
    }

    /**
     * Saves [bytes] into the Klhu album under [baseName], overwriting the
     * existing file when one with the same display name is already there.
     */
    fun upsertImage(bytes: ByteArray, mimeType: String, baseName: String): Uri {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            findAlbumUri("$baseName.jpg")?.let { uri ->
                context.contentResolver.openOutputStream(uri, "wt")?.use {
                    it.write(bytes)
                } ?: throw IOException("openOutputStream failed")
                uri
            } ?: saveToMediaStore(bytes, mimeType, baseName)
        } else {
            val dir = Environment.getExternalStoragePublicDirectory(
                "${Environment.DIRECTORY_PICTURES}/$ALBUM")
            val file = java.io.File(dir, "$baseName.jpg")
            if (file.exists()) {
                file.writeBytes(bytes)
                Uri.fromFile(file)
            } else {
                saveToPublicDirectory(bytes, mimeType, baseName)
            }
        }
    }

    /** Returns the MediaStore URI of the Klhu-album image named [displayName]. */
    private fun findAlbumUri(displayName: String): Uri? {
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val projection = arrayOf(MediaStore.Images.Media._ID)
        val selection = "${MediaStore.Images.Media.DISPLAY_NAME}=? AND " +
            "${MediaStore.Images.Media.RELATIVE_PATH}=?"
        val selectionArgs = arrayOf(displayName, "${Environment.DIRECTORY_PICTURES}/$ALBUM/")
        context.contentResolver.query(collection, projection, selection, selectionArgs, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
                    return android.content.ContentUris.withAppendedId(collection, id)
                }
            }
        return null
    }

    /** Deletes an image previously returned by [saveImage]/[upsertImage]. */
    fun deleteImage(uri: Uri): Boolean {
        return try {
            if (uri.scheme == "file") {
                uri.path?.let { java.io.File(it).delete() } ?: false
            } else {
                context.contentResolver.delete(uri, null, null) > 0
            }
        } catch (e: Exception) {
            false
        }
    }

    /** API 29+: insert into MediaStore Pictures/Klhu, publish when bytes are written. */
    private fun saveToMediaStore(bytes: ByteArray, mimeType: String, baseName: String): Uri {
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "$baseName.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, MIME_JPEG)
            put(MediaStore.Images.Media.BUCKET_DISPLAY_NAME, ALBUM)
            put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/$ALBUM")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = context.contentResolver.insert(collection, values)
            ?: throw IOException("MediaStore insert failed")
        try {
            context.contentResolver.openOutputStream(uri)?.use { out ->
                bytes.inputStream().copyTo(out)
            } ?: throw IOException("openOutputStream failed")
        } catch (e: Exception) {
            context.contentResolver.delete(uri, null, null)
            throw e
        }
        // Publish: image becomes visible in Gallery.
        val published = ContentValues().apply {
            put(MediaStore.Images.Media.IS_PENDING, 0)
        }
        context.contentResolver.update(uri, published, null, null)
        return uri
    }

    /** API 24-28: write to public Pictures/Klhu and scan. */
    private fun saveToPublicDirectory(bytes: ByteArray, mimeType: String, baseName: String): Uri {
        val dir = Environment.getExternalStoragePublicDirectory("${Environment.DIRECTORY_PICTURES}/$ALBUM")
        if (!dir.exists() && !dir.mkdirs()) {
            throw IOException("Could not create directory: ${dir.absolutePath}")
        }
        val file = java.io.File(dir, "$baseName.jpg")
        file.writeBytes(bytes)
        // Announce to gallery.
        android.media.MediaScannerConnection.scanFile(
            context,
            arrayOf(file.absolutePath),
            arrayOf(MIME_JPEG),
        ) { _, uri -> /* uri returned but we already have the file path */ }
        return Uri.fromFile(file)
    }
}
