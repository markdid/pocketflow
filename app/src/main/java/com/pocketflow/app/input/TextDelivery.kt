package com.pocketflow.app.input

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import com.pocketflow.app.hotkey.DictationAccessibilityService
import com.pocketflow.app.ime.PocketFlowImeService

/**
 * Delivers transcript text into the focused app.
 * RustDesk path: IME typing only. Never auto-copy (clipboard overlay stole the UX).
 */
object TextDelivery {
    private const val TAG = "PocketFlow"
    const val OUR_IME = "com.pocketflow.app/.ime.PocketFlowImeService"
    const val GBOARD_IME =
        "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME"

    fun deliver(context: Context, text: String): DeliveryResult {
        if (text.isEmpty()) return DeliveryResult(false, "Empty transcript")

        val pkg = DictationAccessibilityService.focusedPackage().orEmpty()
        val remote = isRemoteDesktop(pkg) ||
            DictationAccessibilityService.isRemoteDesktopVisible()
        Log.i(TAG, "deliver len=${text.length} pkg=$pkg remote=$remote")

        DictationAccessibilityService.clearSoftKeyboardOverride()
        ensurePocketFlowIme(context)
        SystemClock.sleep(100)

        // Always try IME typing first — this is what reaches RustDesk.
        if (deliverViaIme(context, text, forceSwitch = true)) {
            return DeliveryResult(true, "")
        }

        if (!remote && DictationAccessibilityService.insertText(text)) {
            return DeliveryResult(true, "")
        }

        Log.w(TAG, "deliver failed (remote=$remote); not copying to clipboard")
        return DeliveryResult(
            false,
            if (remote) {
                "Couldn't type into RustDesk — click the Mac text field, then dictate again"
            } else {
                "Couldn't insert text"
            },
        )
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
            // Do not fall back to whole-string commitText for remote — that path
            // reported success without typing into RustDesk.
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

    fun switchToGboard(context: Context): Boolean {
        if (currentIme(context) == GBOARD_IME) return true
        return switchIme(context, GBOARD_IME)
    }

    fun isRemoteDesktop(pkg: String): Boolean {
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
