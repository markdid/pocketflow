package com.pocketflow.app.hotkey

import android.accessibilityservice.AccessibilityService
import android.content.ClipData
import android.content.ClipboardManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.pocketflow.app.PocketFlowApp
import com.pocketflow.app.data.HotkeyMode
import com.pocketflow.app.dictation.DictationBus
import com.pocketflow.app.dictation.DictationService
import com.pocketflow.app.dictation.DictationState

/**
 * Global Bluetooth hotkeys + text insert.
 *
 * Hold = talk; release = finish. Double-tap = latch until next tap.
 *
 * RustDesk note: Alt alone engages crosshair/gesture UI. We therefore:
 * - Prefer **Ctrl+Shift+Space**
 * - Swallow chord modifiers (Shift/Alt) while Ctrl is held so RustDesk never sees them
 */
class DictationAccessibilityService : AccessibilityService() {

    private val mainHandler = Handler(Looper.getMainLooper())

    private var chordDownAt = 0L
    private var chordHeld = false
    private var latched = false
    private var pendingShortReleaseStop: Runnable? = null
    private var lastShortReleaseAt = 0L
    private var activeTriggerKey = KeyEvent.KEYCODE_UNKNOWN

    private var ctrlDown = false
    private var swallowedShift = false
    private var swallowedAlt = false

    override fun onServiceConnected() {
        instance = this
        DictationBus.setAccessibilityConnected(true)
        Log.i(TAG, "Accessibility connected")
    }

    override fun onDestroy() {
        cancelPendingStop()
        if (instance === this) {
            instance = null
            DictationBus.setAccessibilityConnected(false)
        }
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onKeyEvent(event: KeyEvent): Boolean {
        // Caps Lock mode: only intercept Caps Lock. Never touch Ctrl/Shift/letter
        // combos so RustDesk keeps receiving Ctrl+S / Ctrl+V.
        val mode = PocketFlowApp.instance.settings.hotkeyMode.value
        if (mode == HotkeyMode.CAPS_LOCK) {
            if (event.keyCode != KeyEvent.KEYCODE_CAPS_LOCK) return false
            if (shouldLog(event)) {
                Log.i(TAG, "caps action=${actionName(event.action)} repeat=${event.repeatCount}")
            }
            if (event.action == KeyEvent.ACTION_UP &&
                chordHeld &&
                !latched &&
                activeTriggerKey == KeyEvent.KEYCODE_CAPS_LOCK
            ) {
                return onTriggerUp()
            }
            return when (event.action) {
                KeyEvent.ACTION_DOWN -> onTriggerDown(event)
                KeyEvent.ACTION_UP -> true
                else -> false
            }
        }

        if (shouldLog(event)) {
            Log.i(
                TAG,
                "key action=${actionName(event.action)} code=${event.keyCode} " +
                    "name=${KeyEvent.keyCodeToString(event.keyCode)} " +
                    "meta=0x${Integer.toHexString(event.metaState)} " +
                    "ctrlDown=$ctrlDown swallowedShift=$swallowedShift swallowedAlt=$swallowedAlt",
            )
        }

        // Track Ctrl (must still reach apps when used alone for remote shortcuts).
        if (isCtrlKey(event.keyCode)) {
            ctrlDown = event.action != KeyEvent.ACTION_UP
            if (!ctrlDown) {
                swallowedShift = false
                swallowedAlt = false
            }
            return false
        }

        // Swallow Shift/Alt while Ctrl is held only for chord modes that need it.
        if (ctrlDown && shouldSwallowPartnerModifier(event)) {
            when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    if (isShiftKey(event.keyCode)) swallowedShift = true
                    if (isAltKey(event.keyCode)) swallowedAlt = true
                    Log.i(TAG, "swallowed ${KeyEvent.keyCodeToString(event.keyCode)} for chord")
                }
                KeyEvent.ACTION_UP -> {
                    if (isShiftKey(event.keyCode)) swallowedShift = false
                    if (isAltKey(event.keyCode)) swallowedAlt = false
                }
            }
            return true
        }

        if (event.action == KeyEvent.ACTION_UP &&
            chordHeld &&
            !latched &&
            activeTriggerKey != KeyEvent.KEYCODE_UNKNOWN &&
            event.keyCode == activeTriggerKey
        ) {
            return onTriggerUp()
        }

        val trigger = matchTrigger(event)
        if (trigger == Trigger.NONE) return false

        return when (event.action) {
            KeyEvent.ACTION_DOWN -> onTriggerDown(event)
            KeyEvent.ACTION_UP -> true
            else -> false
        }
    }

    private fun shouldSwallowPartnerModifier(event: KeyEvent): Boolean {
        val mode = PocketFlowApp.instance.settings.hotkeyMode.value
        val shift = isShiftKey(event.keyCode)
        val alt = isAltKey(event.keyCode)
        return when (mode) {
            HotkeyMode.CTRL_SHIFT_SPACE -> shift
            HotkeyMode.CTRL_ALT_SPACE -> alt
            HotkeyMode.ALL -> shift || alt
            HotkeyMode.CAPS_LOCK, HotkeyMode.ALT_SPACE, HotkeyMode.FN_ALT -> false
        }
    }

    private fun onTriggerDown(event: KeyEvent): Boolean {
        if (event.repeatCount != 0) return true

        val listening = DictationBus.status.value.state == DictationState.LISTENING

        if (listening && latched) {
            Log.i(TAG, "latched tap → stop")
            latched = false
            chordHeld = false
            activeTriggerKey = KeyEvent.KEYCODE_UNKNOWN
            cancelPendingStop()
            DictationService.stop(this)
            return true
        }

        val now = System.currentTimeMillis()
        if (listening && !latched && now - lastShortReleaseAt <= DOUBLE_TAP_MS) {
            Log.i(TAG, "double-tap → latch")
            cancelPendingStop()
            latched = true
            chordHeld = false
            activeTriggerKey = KeyEvent.KEYCODE_UNKNOWN
            DictationBus.setState(DictationState.LISTENING, "Latched — tap Caps Lock again to finish")
            return true
        }

        if (listening) return true

        cancelPendingStop()
        chordDownAt = now
        chordHeld = true
        latched = false
        activeTriggerKey = event.keyCode
        Log.i(TAG, "hold start key=${KeyEvent.keyCodeToString(event.keyCode)}")
        DictationService.start(this)
        return true
    }

    private fun onTriggerUp(): Boolean {
        if (!chordHeld || latched) return true

        chordHeld = false
        val heldFor = System.currentTimeMillis() - chordDownAt
        activeTriggerKey = KeyEvent.KEYCODE_UNKNOWN
        Log.i(TAG, "hold release after ${heldFor}ms")

        if (heldFor >= HOLD_MS) {
            cancelPendingStop()
            DictationService.stop(this)
            return true
        }

        lastShortReleaseAt = System.currentTimeMillis()
        cancelPendingStop()
        val stop = Runnable {
            if (latched) return@Runnable
            if (DictationBus.status.value.state == DictationState.LISTENING) {
                Log.i(TAG, "short-tap timeout → stop")
                DictationService.stop(this)
            }
        }
        pendingShortReleaseStop = stop
        mainHandler.postDelayed(stop, DOUBLE_TAP_MS)
        return true
    }

    private fun cancelPendingStop() {
        pendingShortReleaseStop?.let { mainHandler.removeCallbacks(it) }
        pendingShortReleaseStop = null
    }

    private fun matchTrigger(event: KeyEvent): Trigger {
        val mode = PocketFlowApp.instance.settings.hotkeyMode.value
        val caps = event.keyCode == KeyEvent.KEYCODE_CAPS_LOCK
        val ctrlShift = isCtrlShiftSpace(event)
        val ctrlAlt = isCtrlAltSpace(event)
        val altSpace = isAltSpace(event)

        return when (mode) {
            HotkeyMode.CAPS_LOCK ->
                if (caps) Trigger.CAPS_LOCK else Trigger.NONE
            HotkeyMode.CTRL_SHIFT_SPACE ->
                if (ctrlShift) Trigger.CTRL_SHIFT_SPACE else Trigger.NONE
            HotkeyMode.CTRL_ALT_SPACE ->
                if (ctrlAlt) Trigger.CTRL_ALT_SPACE else Trigger.NONE
            HotkeyMode.ALT_SPACE ->
                if (altSpace) Trigger.ALT_SPACE else Trigger.NONE
            HotkeyMode.FN_ALT ->
                if (isFnAlt(event)) Trigger.FN_ALT else Trigger.NONE
            HotkeyMode.ALL -> when {
                caps -> Trigger.CAPS_LOCK
                ctrlShift -> Trigger.CTRL_SHIFT_SPACE
                ctrlAlt -> Trigger.CTRL_ALT_SPACE
                altSpace -> Trigger.ALT_SPACE
                isFnAlt(event) -> Trigger.FN_ALT
                else -> Trigger.NONE
            }
        }
    }

    private fun isCtrlShiftSpace(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_SPACE) return false
        val meta = event.metaState
        val ctrl = ctrlDown || meta and KeyEvent.META_CTRL_MASK != 0
        val shift = swallowedShift || meta and KeyEvent.META_SHIFT_MASK != 0
        val alt = swallowedAlt || meta and KeyEvent.META_ALT_MASK != 0
        return ctrl && shift && !alt
    }

    private fun isCtrlAltSpace(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_SPACE) return false
        val meta = event.metaState
        val ctrl = ctrlDown || meta and KeyEvent.META_CTRL_MASK != 0
        val alt = swallowedAlt || meta and KeyEvent.META_ALT_MASK != 0
        return ctrl && alt
    }

    private fun isAltSpace(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_SPACE) return false
        val meta = event.metaState
        val alt = meta and KeyEvent.META_ALT_MASK != 0
        val ctrl = ctrlDown || meta and KeyEvent.META_CTRL_MASK != 0
        return alt && !ctrl
    }

    private fun isFnAlt(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_SPACE) return false
        val meta = event.metaState
        val alt = swallowedAlt || meta and KeyEvent.META_ALT_MASK != 0
        val fnMeta = meta and KeyEvent.META_META_MASK != 0 ||
            meta and KeyEvent.META_FUNCTION_ON != 0
        return fnMeta && alt
    }

    private fun isCtrlKey(code: Int) =
        code == KeyEvent.KEYCODE_CTRL_LEFT || code == KeyEvent.KEYCODE_CTRL_RIGHT

    private fun isShiftKey(code: Int) =
        code == KeyEvent.KEYCODE_SHIFT_LEFT || code == KeyEvent.KEYCODE_SHIFT_RIGHT

    private fun isAltKey(code: Int) =
        code == KeyEvent.KEYCODE_ALT_LEFT || code == KeyEvent.KEYCODE_ALT_RIGHT

    private fun shouldLog(event: KeyEvent): Boolean {
        if (event.repeatCount > 0) return false
        val code = event.keyCode
        return isCtrlKey(code) || isShiftKey(code) || isAltKey(code) ||
            code == KeyEvent.KEYCODE_CAPS_LOCK ||
            code == KeyEvent.KEYCODE_FUNCTION ||
            code == KeyEvent.KEYCODE_META_LEFT ||
            code == KeyEvent.KEYCODE_META_RIGHT ||
            code == KeyEvent.KEYCODE_SPACE ||
            event.metaState != 0
    }

    private fun actionName(action: Int): String = when (action) {
        KeyEvent.ACTION_DOWN -> "DOWN"
        KeyEvent.ACTION_UP -> "UP"
        else -> action.toString()
    }

    private enum class Trigger {
        NONE, CAPS_LOCK, CTRL_SHIFT_SPACE, CTRL_ALT_SPACE, ALT_SPACE, FN_ALT
    }

    companion object {
        private const val TAG = "PocketFlow"
        private const val HOLD_MS = 220L
        private const val DOUBLE_TAP_MS = 380L

        @Volatile
        private var instance: DictationAccessibilityService? = null

        fun isEnabled(): Boolean = instance != null

        fun focusedPackage(): String? =
            instance?.rootInActiveWindow?.packageName?.toString()

        fun copyToClipboard(text: String) {
            copyToClipboardQuiet(text)
        }

        /** Prefer this — marks clip sensitive to avoid the Android 13+ preview toast. */
        fun copyToClipboardQuiet(text: String) {
            val service = instance ?: return
            val clipboard = service.getSystemService(ClipboardManager::class.java)
            val clip = ClipData.newPlainText("", text)
            clip.description.extras = android.os.PersistableBundle().apply {
                putBoolean("android.content.extra.IS_SENSITIVE", true)
            }
            clipboard.setPrimaryClip(clip)
        }

        fun clickByText(substring: String): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false
            val matches = root.findAccessibilityNodeInfosByText(substring) ?: return false
            for (node in matches) {
                var current: AccessibilityNodeInfo? = node
                while (current != null) {
                    if (current.isClickable) {
                        val ok = current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        Log.i(TAG, "clickByText '$substring' ok=$ok")
                        if (ok) return true
                    }
                    current = current.parent
                }
            }
            return false
        }

        fun insertText(text: String): Boolean {
            val service = instance ?: return false
            // Do not copy here — callers decide; avoids clipboard toast on success.

            val pkg = focusedPackage()
            Log.i(TAG, "insertText into pkg=$pkg")

            if (pkg != null && isRemoteDesktopPackage(pkg)) {
                Log.i(TAG, "remote desktop detected — skip a11y insert, need IME/clipboard")
                return false
            }

            val root = service.rootInActiveWindow ?: return false
            val focus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                ?: service.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)

            if (focus != null) {
                if (focus.isEditable && setTextPreservingRealContent(focus, text)) {
                    Log.i(TAG, "inserted via SET_TEXT")
                    return true
                }
                copyToClipboardQuiet(text)
                if (focus.performAction(AccessibilityNodeInfo.ACTION_PASTE)) {
                    Log.i(TAG, "inserted via PASTE")
                    return true
                }
            }

            val editable = findEditable(root)
            if (editable != null) {
                if (setTextPreservingRealContent(editable, text)) return true
                copyToClipboardQuiet(text)
                if (editable.performAction(AccessibilityNodeInfo.ACTION_PASTE)) return true
            }
            return false
        }

        private fun isRemoteDesktopPackage(pkg: String): Boolean {
            val p = pkg.lowercase()
            return p.contains("rustdesk") ||
                p.contains("anydesk") ||
                p.contains("teamviewer") ||
                p.contains("chrome.remote") ||
                p.contains("vnc") ||
                p.contains("rdp")
        }

        private fun setTextPreservingRealContent(
            node: AccessibilityNodeInfo,
            addition: String,
        ): Boolean {
            val real = realEditableText(node)
            val combined = when {
                real.isEmpty() -> addition
                real.endsWith(" ") || addition.startsWith(" ") -> real + addition
                else -> "$real $addition"
            }
            val args = android.os.Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    combined,
                )
            }
            return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        }

        private fun realEditableText(node: AccessibilityNodeInfo): String {
            val raw = node.text?.toString().orEmpty()
            if (raw.isBlank()) return ""
            val hint = node.hintText?.toString().orEmpty()
            if (hint.isNotBlank() && raw.equals(hint, ignoreCase = true)) return ""
            val placeholders = setOf(
                "message", "type a message", "type message", "write a message",
                "send a message", "text message", "start messaging", "say something", "compose",
            )
            if (placeholders.contains(raw.trim().lowercase())) return ""
            return raw
        }

        private fun findEditable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            if (node.isEditable && node.isFocused) return node
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                val found = findEditable(child)
                if (found != null) return found
            }
            return null
        }
    }
}
