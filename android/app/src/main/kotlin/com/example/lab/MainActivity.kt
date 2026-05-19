package com.example.lab

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingImageResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> pickImage(result)
                    "getString" -> {
                        val key = call.argument<String>("key")
                        result.success(prefs().getString(key, null))
                    }
                    "setString" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        if (key.isNullOrBlank() || value == null) {
                            result.error("invalid_args", "Invalid preference value", null)
                        } else {
                            prefs().edit().putString(key, value).apply()
                            result.success(null)
                        }
                    }
                    "remove" -> {
                        val key = call.argument<String>("key")
                        prefs().edit().remove(key).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != REQUEST_PICK_IMAGE) {
            return
        }

        val result = pendingImageResult ?: return
        pendingImageResult = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        try {
            result.success(copyImageToCache(uri))
        } catch (ex: Exception) {
            result.error("copy_failed", ex.message, null)
        }
    }

    private fun pickImage(result: MethodChannel.Result) {
        if (pendingImageResult != null) {
            result.error("busy", "Image picker is already open", null)
            return
        }

        pendingImageResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        startActivityForResult(intent, REQUEST_PICK_IMAGE)
    }

    private fun copyImageToCache(uri: Uri): String {
        val target = File(cacheDir, "barcode_photo_${System.currentTimeMillis()}.jpg")
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Cannot open image" }
            target.outputStream().use { output -> input.copyTo(output) }
        }
        return target.absolutePath
    }

    private fun prefs() = getSharedPreferences("cashdesk_mobile", MODE_PRIVATE)

    companion object {
        private const val CHANNEL = "cashdesk_mobile/native"
        private const val REQUEST_PICK_IMAGE = 4117
    }
}
