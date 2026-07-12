package com.example.like_local

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "like_local/original_media_picker"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickImages" -> pickImages(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pickImages(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Another image picker request is already running.", null)
            return
        }

        pendingResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.ACCESS_MEDIA_LOCATION),
                REQUEST_MEDIA_LOCATION
            )
            return
        }

        launchPicker()
    }

    private fun launchPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, REQUEST_PICK_IMAGES)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_MEDIA_LOCATION) {
            return
        }

        launchPicker()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_IMAGES) {
            return
        }

        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        try {
            val uris = mutableListOf<Uri>()
            val clipData = data.clipData
            if (clipData != null) {
                for (index in 0 until clipData.itemCount) {
                    uris.add(clipData.getItemAt(index).uri)
                }
            } else {
                data.data?.let { uris.add(it) }
            }

            val files = uris.mapIndexedNotNull { index, uri ->
                copyOriginalImage(uri, index)
            }
            result.success(files)
        } catch (error: Exception) {
            result.error("copy_failed", error.message, null)
        }
    }

    private fun copyOriginalImage(uri: Uri, index: Int): Map<String, String>? {
        val readableUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                MediaStore.setRequireOriginal(uri)
            } catch (_: Exception) {
                uri
            }
        } else {
            uri
        }

        contentResolver.takePersistableUriPermissionIfPossible(uri)

        val fileName = queryDisplayName(uri) ?: "picked_image_$index.jpg"
        val outputFile = File(cacheDir, "original_${System.nanoTime()}_$fileName")

        openInputStreamWithFallback(readableUri, uri)?.use { input ->
            outputFile.outputStream().use { output ->
                input.copyTo(output)
            }
        } ?: return null

        return mapOf("path" to outputFile.absolutePath, "name" to fileName)
    }

    private fun openInputStreamWithFallback(primaryUri: Uri, fallbackUri: Uri): InputStream? {
        try {
            return contentResolver.openInputStream(primaryUri)
        } catch (error: SecurityException) {
            if (primaryUri == fallbackUri) {
                throw error
            }
        } catch (error: IllegalArgumentException) {
            if (primaryUri == fallbackUri) {
                throw error
            }
        }

        return contentResolver.openInputStream(fallbackUri)
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(
            uri,
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                if (index >= 0) {
                    return cursor.getString(index)
                }
            }
        }
        return null
    }

    private fun android.content.ContentResolver.takePersistableUriPermissionIfPossible(uri: Uri) {
        try {
            takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) {
            // Some providers do not grant persistable permissions; a one-time
            // read is enough because we immediately copy the original bytes.
        }
    }

    companion object {
        private const val REQUEST_MEDIA_LOCATION = 8101
        private const val REQUEST_PICK_IMAGES = 8102
    }
}
