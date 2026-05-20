package com.yuyuan.assetledger

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val pendingShareFiles: ArrayDeque<Map<String, String>> = ArrayDeque()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePending" -> {
                        val next =
                            if (pendingShareFiles.isEmpty()) null
                            else pendingShareFiles.removeFirst()
                        result.success(next)
                    }
                    else -> result.notImplemented()
                }
            }
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_VIEW) return
        val uri: Uri = intent.data ?: return
        val payload = readShareFile(uri) ?: return
        pendingShareFiles.addLast(payload)
    }

    private fun readShareFile(uri: Uri): Map<String, String>? {
        return try {
            val resolver: ContentResolver = applicationContext.contentResolver
            val text = resolver.openInputStream(uri)?.use { input ->
                BufferedReader(InputStreamReader(input, Charsets.UTF_8)).use { it.readText() }
            } ?: return null
            mapOf("content" to text, "name" to resolveDisplayName(resolver, uri))
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveDisplayName(resolver: ContentResolver, uri: Uri): String {
        if (uri.scheme == "file") {
            return uri.lastPathSegment.orEmpty()
        }
        return try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) cursor.getString(idx).orEmpty() else uri.lastPathSegment.orEmpty()
                    } else {
                        uri.lastPathSegment.orEmpty()
                    }
                } ?: uri.lastPathSegment.orEmpty()
        } catch (_: Exception) {
            uri.lastPathSegment.orEmpty()
        }
    }

    companion object {
        private const val SHARE_CHANNEL_NAME = "com.yuyuan.assetledger/share_inbox"
    }
}
