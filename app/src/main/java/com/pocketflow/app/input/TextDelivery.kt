package com.pocketflow.app.input

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import com.pocketflow.app.hotkey.DictationAccessibilityService
import com.pocketflow.app.ime.PocketFlowImeService

/**
 * Delivers transcript text into the focused app, with a RustDesk-oriented path:
 * keep PocketFlow IME selected while armed, and type via key events / commitText.
 */
object TextDelivery {
    private const val TAG = "PocketFlow"
    const val OUR_IME = "com.pocketflow.app/.ime.PocketFlowImeService"

    fun deliver(context: Context, text: String): DeliveryResult {
        if (text.isEmpty()) return DeliveryResult(false, "Empty transcript")

        val pkg = DictationAccessibilityService.focusedPackage().orEmpty()
        val remote = isRemoteDesktop(pkg)
        Log.i(TAG, "deliver len=${text.length} pkg=$pkg remote=$remote")

        // 1) Prefer IME typing — no clipboard toast on success.
        val imeOk = deliverViaIme(context, text, forceSwitch = remote || !PocketFlowImeService.isActive())
        if (imeOk) {
            return DeliveryResult(true, "")
        }

        // 2) Local Android editable.
        if (!remote && DictationAccessibilityService.insertText(text)) {
            return DeliveryResult(true, "")
        }

        DictationAccessibilityService.copyToClipboardQuiet(text)

        if (remote && PocketFlowImeService.pasteClipboardChord()) {
            return DeliveryResult(true, "")
        }

        if (remote && DictationAccessibilityService.clickByText("Send clipboard keystrokes")) {
            return DeliveryResult(true, "")
        }
        if (remote && DictationAccessibilityService.clickByText("clipboard keystrokes")) {
            return DeliveryResult(true, "")
        }

        if (typeViaShellInput(text)) {
            return DeliveryResult(true, "")
        }

        return DeliveryResult(
            false,
            if (remote) {
                "In RustDesk: Actions → Send clipboard keystrokes"
            } else {
                "Ready on clipboard"
            },
        )
    }

    private fun typeViaShellInput(text: String): Boolean {
        return try {
            val escaped = text
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace(" ", "%s")
                .replace("'", "")
                .replace("\n", "%s")
            val proc = ProcessBuilder("sh", "-c", "input text \"$escaped\"")
                .redirectErrorStream(true)
                .start()
            val code = proc.waitFor()
            val out = proc.inputStream.bufferedReader().readText()
            Log.i(TAG, "shell input exit=$code out=$out")
            code == 0
        } catch (t: Throwable) {
            Log.w(TAG, "shell input failed", t)
            false
        }
    }

    private fun deliverViaIme(context: Context, text: String, forceSwitch: Boolean): Boolean {
        try {
            if (forceSwitch && currentIme(context) != OUR_IME) {
                if (!switchIme(context, OUR_IME)) {
                    Log.w(TAG, "IME switch failed (need WRITE_SECURE_SETTINGS)")
                } else {
                    SystemClock.sleep(250)
                }
            }

            if (PocketFlowImeService.typeAsKeyEvents(text)) return true
            if (PocketFlowImeService.commitTextIfActive(text)) return true
            return false
        } catch (t: Throwable) {
            Log.w(TAG, "deliverViaIme failed", t)
            return false
        }
    }

    private fun currentIme(context: Context): String =
        Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            .orEmpty()

    private fun switchIme(context: Context, imeId: String): Boolean {
        return try {
            val ok = Settings.Secure.putString(
                context.contentResolver,
                Settings.Secure.DEFAULT_INPUT_METHOD,
                imeId,
            )
            Log.i(TAG, "switchIme $imeId ok=$ok")
            ok
        } catch (t: Throwable) {
            Log.w(TAG, "switchIme failed", t)
            false
        }
    }

    fun ensurePocketFlowIme(context: Context): Boolean {
        if (currentIme(context) == OUR_IME) return true
        return switchIme(context, OUR_IME)
    }

    private fun isRemoteDesktop(pkg: String): Boolean {
        val p = pkg.lowercase()
        return p.contains("rustdesk") ||
            p.contains("flutter_hbb") ||
            p.contains("carriez") ||
            p.contains("anydesk") ||
            p.contains("teamviewer") ||
            p.contains("vnc") ||
            p.contains("rdp")
    }

    data class DeliveryResult(val success: Boolean, val message: String)
}
