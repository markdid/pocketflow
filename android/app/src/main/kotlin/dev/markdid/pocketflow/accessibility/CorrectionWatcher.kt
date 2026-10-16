package dev.markdid.pocketflow.accessibility

import android.os.Handler
import android.os.Looper

/**
 * After PocketFlow inserts text, follows that field's edits for up to a minute. When the user leaves the app,
 * dictates again, or time runs out, hands the inserted text and the field's final text to the learner.
 *
 * Only the latest text of the one app is held in memory; nothing is stored or sent unless it differs from what was
 * inserted, and then only the changed words (with a few words of context) reach the model.
 */
class CorrectionWatcher {
    private val handler = Handler(Looper.getMainLooper())
    private var pkg: String? = null
    private var inserted: String? = null
    private var latest: String? = null
    private var onFinished: ((String, String) -> Unit)? = null
    private val timeout = Runnable { finish() }

    fun start(pkg: String?, inserted: String, onFinished: (String, String) -> Unit) {
        finish()
        if (pkg == null) return
        this.pkg = pkg
        this.inserted = inserted
        this.onFinished = onFinished
        handler.postDelayed(timeout, WATCH_MS)
    }

    fun onTextChanged(eventPackage: String?, text: String) {
        if (pkg != null && eventPackage == pkg) latest = text
    }

    fun onAppChanged(eventPackage: String?) {
        // System UI (notification shade, keyboard) passes through without ending the watch.
        if (pkg == null || eventPackage == null || eventPackage == pkg) return
        if (eventPackage.startsWith("com.android.systemui") || eventPackage.contains("inputmethod")) return
        finish()
    }

    fun finish() {
        handler.removeCallbacks(timeout)
        val original = inserted
        val final = latest
        val callback = onFinished
        pkg = null
        inserted = null
        latest = null
        onFinished = null
        if (original != null && final != null && callback != null && !final.contains(original)) callback(original, final)
    }

    private companion object {
        const val WATCH_MS = 60_000L
    }
}
