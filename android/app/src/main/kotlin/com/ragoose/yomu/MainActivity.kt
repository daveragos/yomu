package com.ragoose.yomu

import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        fillMissingType(intent)
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun onNewIntent(intent: Intent) {
        fillMissingType(intent)
        super.onNewIntent(intent)
    }

    /**
     * receive_sharing_intent only treats a VIEW intent as a file when the
     * sending app set a MIME type. Some apps open files without one, so fill
     * it in from the content provider (or fall back to a generic binary type)
     * before Flutter sees the intent.
     */
    private fun fillMissingType(intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_VIEW || intent.type != null) return
        val data = intent.data ?: return
        if (data.scheme != "content" && data.scheme != "file") return
        val type = if (data.scheme == "content") {
            runCatching { contentResolver.getType(data) }.getOrNull()
        } else {
            null
        }
        intent.setDataAndType(data, type ?: "application/octet-stream")
    }
}
