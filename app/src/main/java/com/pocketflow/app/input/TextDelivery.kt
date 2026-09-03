package com.pocketflow.app.input

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import com.pocketflow.app.hotkey.DictationAccessibilityService
import com.pocketflow.app.ime.PocketFlowImeService

/**
 * Delivers transcript text into the focused app, with a RustDesk-oriented path:
 * temporarily select PocketFlow IME (needs WRITE_SECURE_SETTINGS), then type via
 * key events / commitText so Flutter_hbb forwards them like a soft/hardware keyboard.
 */
object TextDelivery {
    private const val TAG = "PocketFlow"
    private const val OUR_IME =
        "com.pocketflow.app/.ime.PocketFlowImeService"

    fun deliver(context: Context, text: String): DeliveryResult {
        if (text.isEmpty()) return DeliveryResult(false, "Empty transcript")

        val pkg = DictationAccessibilityService.focusedPackage().orEmpty()
        val remote = isRemoteDesktop(pkg)
        Log.i(TAG, "deliver len=${text.length} pkg=$pkg remote=$remote")

        // Always keep a clipboard copy as safety net.
        DictationAccessibilityService.copyToClipboard(text)

        // 1) Prefer IME typing (works for local fields + RustDesk when IME is ours).
        val imeOk = deliverViaIme(context, text, forceSwitch = remote || !PocketFlowImeService.isActive())
        if (imeOk) {
            return DeliveryResult(true, if (remote) "Typed into remote via keyboard" else "Inserted via keyboard")
        }

        // 2) Local Android editable: accessibility paste / set-text.
        if (!remote && DictationAccessibilityService.insertText(text)) {
            return DeliveryResult(true, "Inserted")
        }

        // 3) RustDesk fallback: clipboard is set; try IME Ctrl+V chord.
        if (remote && PocketFlowImeService.pasteClipboardChord()) {
            return DeliveryResult(true, "Pasted into remote (Ctrl+V)")
        }

        // 4) Tap RustDesk's "Send clipboard keystrokes" action if visible.
        if (remote && DictationAccessibilityService.clickByText("Send clipboard keystrokes")) {
            return DeliveryResult(true, "Sent via RustDesk clipboard keystrokes")
        }
        if (remote && DictationAccessibilityService.clickByText("clipboard keystrokes")) {
            return DeliveryResult(true, "Sent via RustDesk clipboard keystrokes")
        }

        // 5) Last-ditch: shell `input text` (works if the environment allows inject).
        if (typeViaShellInput(text)) {
            return DeliveryResult(true, "Typed via system input")
        }

        return DeliveryResult(
            false,
            if (remote) {
                "Copied — in RustDesk open ⋮ Actions → Send clipboard keystrokes"
            } else {
                "Copied to clipboard"
            },
        )
    }

    private fun typeViaShellInput(text: String): Boolean {
        return try {
            // `input text` treats spaces as %s and is ASCII-oriented.
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
        var previousIme: String? = null
        try {
            if (forceSwitch) {
                previousIme = currentIme(context)
                if (previousIme != OUR_IME) {
                    if (!switchIme(context, OUR_IME)) {
                        Log.w(TAG, "IME switch failed (need WRITE_SECURE_SETTINGS)")
                    } else {
                        // Give the system a beat to bind the IME to the focused app.
                        SystemClock.sleep(250)
                    }
                }
            }

            // Try key-event typing first — closer to hardware keyboard (RustDesk-friendly).
            if (PocketFlowImeService.typeAsKeyEvents(text)) {
                return true
            }
            if (PocketFlowImeService.commitTextIfActive(text)) {
                return true
            }
            return false
        } finally {
            // Stay on PocketFlow while armed for seamless repeat dictation in RustDesk.
            // Only restore if we switched away from a different IME and delivery failed paths
            // that need Gboard — actually keep PocketFlow; user can change back in settings.
            // If we switched and want to restore non-remote:
            val pkg = DictationAccessibilityService.focusedPackage().orEmpty()
            if (!isRemoteDesktop(pkg) && previousIme != null && previousIme != OUR_IME) {
                switchIme(context, previousIme)
            }
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
            // Nudge IMM
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
