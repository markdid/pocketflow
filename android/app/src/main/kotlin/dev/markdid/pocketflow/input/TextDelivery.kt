package dev.markdid.pocketflow.input

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.inputmethod.InputMethodManager
import dev.markdid.pocketflow.PocketFlowApp
import dev.markdid.pocketflow.accessibility.PocketFlowAccessibilityService
import dev.markdid.pocketflow.ime.PocketFlowImeService

/** Gets finished text into whatever the user is typing in. */
object TextDelivery {
    private const val TAG = "PocketFlow"
    const val OUR_IME = "dev.markdid.pocketflow/.ime.PocketFlowImeService"

    enum class Method { KEYBOARD, KEY_EVENTS, ACCESSIBILITY, CLIPBOARD, NONE }

    data class Result(val method: Method, val message: String = "") {
        val success get() = method != Method.NONE && method != Method.CLIPBOARD
    }

    /** Android package of the app being typed into, if known. */
    fun targetApp(): String? = PocketFlowImeService.editorPackage() ?: PocketFlowAccessibilityService.focusedPackage()

    /** True when typing should go key by key into a remote-desktop session (RustDesk and friends). */
    fun isRemoteTarget(): Boolean {
        if (!PocketFlowApp.instance.settings.remoteDesktopTyping) return false
        return isRemoteDesktop(targetApp().orEmpty()) || PocketFlowAccessibilityService.isRemoteDesktopVisible()
    }

    fun deliver(context: Context, text: String): Result {
        if (text.isEmpty()) return Result(Method.NONE, "Nothing to insert")

        if (isRemoteTarget()) return deliverToRemoteDesktop(context, text)

        if (PocketFlowImeService.commitTextIfActive(text)) return Result(Method.KEYBOARD)
        if (PocketFlowAccessibilityService.insertText(text)) return Result(Method.ACCESSIBILITY)

        copyToClipboard(context, text)
        return Result(Method.CLIPBOARD, "Copied. Paste it where you need it.")
    }

    /**
     * RustDesk only reacts to real key events, so switch to the PocketFlow keyboard and type character by character.
     * Never leave the text on the phone clipboard: RustDesk syncs it and the next Cmd+V on the Mac would paste it.
     */
    private fun deliverToRemoteDesktop(context: Context, text: String): Result {
        PocketFlowAccessibilityService.clearSoftKeyboardOverride()
        var switchFailed = false
        if (currentIme(context) != OUR_IME) {
            if (switchToOurIme(context)) {
                SystemClock.sleep(250)
            } else {
                switchFailed = true
                Log.w(TAG, "IME switch failed (needs WRITE_SECURE_SETTINGS)")
            }
        }
        SystemClock.sleep(100)
        Log.i(TAG, "remote delivery: ime=${currentIme(context)} switchFailed=$switchFailed target=${targetApp()}")
        if (PocketFlowImeService.typeAsKeyEvents(text)) {
            clearClipboard(context)
            Handler(Looper.getMainLooper()).postDelayed({ clearClipboard(context) }, 400)
            return Result(Method.KEY_EVENTS)
        }
        val message = when {
            !isOurImeEnabled(context) -> "PocketFlow keyboard is off. Turn it on in Android keyboard settings."
            switchFailed && !canSwitchIme(context) -> "Keyboard switching isn't granted. Run the README's adb grant."
            else -> "Couldn't type into the remote desktop. Click its text field, then dictate again."
        }
        return Result(Method.NONE, message)
    }

    private fun isOurImeEnabled(context: Context): Boolean =
        context.getSystemService(InputMethodManager::class.java).enabledInputMethodList
            .any { it.packageName == context.packageName }

    private fun canSwitchIme(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) == PackageManager.PERMISSION_GRANTED

    /** Pre-selects the PocketFlow keyboard while a remote desktop is open so typing starts instantly. */
    fun prepareForRemoteDesktop(context: Context) {
        if (isRemoteTarget() && currentIme(context) != OUR_IME) switchToOurIme(context)
    }

    /** Switches back to the keyboard remote typing replaced, so tapping a field brings up the usual one again. */
    fun restoreKeyboard(context: Context) {
        val settings = PocketFlowApp.instance.settings
        val previous = settings.keyboardBeforeRemote ?: return
        settings.keyboardBeforeRemote = null
        if (currentIme(context) == OUR_IME && switchIme(context, previous)) Log.i(TAG, "keyboard restored to $previous")
    }

    private fun switchToOurIme(context: Context): Boolean {
        val previous = currentIme(context)
        if (!switchIme(context, OUR_IME)) return false
        if (previous.isNotEmpty() && previous != OUR_IME) {
            PocketFlowApp.instance.settings.keyboardBeforeRemote = previous
        }
        return true
    }

    fun copyToClipboard(context: Context, text: String) {
        // Not marked sensitive: that hides the preview and stops RustDesk from reading the clip.
        context.getSystemService(ClipboardManager::class.java)
            .setPrimaryClip(ClipData.newPlainText("PocketFlow", text))
    }

    private fun clearClipboard(context: Context) {
        runCatching { context.getSystemService(ClipboardManager::class.java).clearPrimaryClip() }
    }

    private fun currentIme(context: Context): String =
        Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD).orEmpty()

    /** Needs `adb shell pm grant dev.markdid.pocketflow android.permission.WRITE_SECURE_SETTINGS`. */
    private fun switchIme(context: Context, imeId: String): Boolean = runCatching {
        Settings.Secure.putString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD, imeId)
    }.getOrDefault(false)

    fun isRemoteDesktop(pkg: String): Boolean {
        val p = pkg.lowercase()
        return listOf("rustdesk", "flutter_hbb", "carriez", "anydesk", "teamviewer", "vnc", "rdp", "chrome.remote")
            .any(p::contains)
    }
}
