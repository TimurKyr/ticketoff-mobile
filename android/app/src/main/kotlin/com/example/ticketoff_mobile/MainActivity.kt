package com.example.ticketoff_mobile

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var documentResult: MethodChannel.Result? = null
    private var documentBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ticketoff/guest_documents")
            .setMethodCallHandler { call, result ->
                if (documentResult != null) {
                    result.error("busy", "A document picker is already open", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "pick" -> {
                        val accepted = call.argument<List<String>>("types").orEmpty()
                            .flatMap { it.split(',') }
                            .mapNotNull { value ->
                                val type = value.trim().lowercase()
                                when {
                                    type.startsWith(".") -> MimeTypeMap.getSingleton()
                                        .getMimeTypeFromExtension(type.drop(1))
                                    '/' in type -> type
                                    else -> null
                                }
                            }
                            .distinct()
                        openDocument(
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = accepted.singleOrNull() ?: "*/*"
                                if (accepted.size > 1) {
                                    putExtra(Intent.EXTRA_MIME_TYPES, accepted.toTypedArray())
                                }
                                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, call.argument<Boolean>("multiple") == true)
                            },
                            PICK_FILE,
                            result,
                        )
                    }
                    "save" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name")
                        if (bytes == null || bytes.isEmpty() || bytes.size > 8 * 1024 * 1024 || name.isNullOrBlank()) {
                            result.error("invalid_file", "Invalid download", null)
                            return@setMethodCallHandler
                        }
                        documentBytes = bytes
                        openDocument(
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = when (name.substringAfterLast('.', "").lowercase()) {
                                    "pdf" -> "application/pdf"
                                    "ics" -> "text/calendar"
                                    "png" -> "image/png"
                                    "jpg", "jpeg" -> "image/jpeg"
                                    "csv" -> "text/csv"
                                    else -> "application/octet-stream"
                                }
                                putExtra(Intent.EXTRA_TITLE, name)
                            },
                            SAVE_FILE,
                            result,
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun openDocument(intent: Intent, requestCode: Int, result: MethodChannel.Result) {
        documentResult = result
        try {
            startActivityForResult(intent, requestCode)
        } catch (_: ActivityNotFoundException) {
            documentResult = null
            documentBytes = null
            result.error("picker_unavailable", "No document picker found", null)
        }
    }

    @Deprecated("Required by FlutterActivity to receive legacy activity results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_FILE && requestCode != SAVE_FILE) return
        val result = documentResult ?: return
        val bytes = documentBytes
        documentResult = null
        documentBytes = null
        if (requestCode == PICK_FILE) {
            val picked = if (resultCode == Activity.RESULT_OK && data != null) {
                data.clipData?.let { clip ->
                    List(clip.itemCount) { clip.getItemAt(it).uri.toString() }
                } ?: listOfNotNull(data.data?.toString())
            } else {
                emptyList()
            }
            result.success(picked)
            return
        }
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                val output = contentResolver.openOutputStream(uri, "w")
                    ?: throw IOException("Unable to open download destination")
                output.use { it.write(bytes) }
                runOnUiThread { result.success(null) }
            } catch (_: IOException) {
                runOnUiThread { result.error("write_failed", "Unable to save download", null) }
            } catch (_: SecurityException) {
                runOnUiThread { result.error("write_failed", "Unable to save download", null) }
            }
        }.start()
    }

    private companion object {
        const val PICK_FILE = 6201
        const val SAVE_FILE = 6202
    }
}
