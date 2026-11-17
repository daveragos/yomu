package com.ragoose.yomu

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val voiceNoteWorker = Executors.newSingleThreadExecutor()
    @Volatile private var voiceNote: VoiceNoteCapture? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Yomu's own voice note recorder (see VoiceNoteCapture): cleans the
        // sound while recording. Starting and stopping run off the main
        // thread; the level is read often and is cheap.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ragoose.yomu/voice_note")
            .setMethodCallHandler { call, result ->
                val main = Handler(Looper.getMainLooper())
                fun background(work: () -> Any?) {
                    voiceNoteWorker.execute {
                        try {
                            val value = work()
                            main.post { result.success(value) }
                        } catch (e: Exception) {
                            main.post { result.error("voice_note", e.message, null) }
                        }
                    }
                }
                when (call.method) {
                    "start" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "path is required", null)
                            return@setMethodCallHandler
                        }
                        background {
                            voiceNote?.cancel()
                            voiceNote = VoiceNoteCapture(path).also { it.start() }
                            null
                        }
                    }
                    "level" -> result.success(voiceNote?.level() ?: -160.0)
                    "stop" -> background {
                        val capture = voiceNote ?: throw IllegalStateException("Not recording")
                        voiceNote = null
                        capture.stop()
                    }
                    "cancel" -> background {
                        voiceNote?.cancel()
                        voiceNote = null
                        null
                    }
                    else -> result.notImplemented()
                }
            }
    }

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
