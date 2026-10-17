package dev.markdid.pocketflow.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.res.Configuration
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import dev.markdid.pocketflow.HotkeyMode
import dev.markdid.pocketflow.PocketFlowApp
import dev.markdid.pocketflow.dictation.DictationBus
import dev.markdid.pocketflow.dictation.DictationService
import dev.markdid.pocketflow.dictation.DictationState
import dev.markdid.pocketflow.input.TextDelivery

/**
 * Runs in the background with the user's permission to:
 * - insert dictated text into the focused field of any app,
 * - show the floating mic bubble next to focused text fields,
 * - turn hardware-keyboard hotkeys into dictation (hold to talk, double-tap to latch),
 * - watch the field briefly after inserting, so corrections can teach PocketFlow new words.
 *
 * Remote desktops: Alt alone engages RustDesk's gesture UI, so chord modes swallow the partner modifier while Ctrl is
 * held and Caps Lock mode touches nothing but Caps Lock.
 */
class PocketFlowAccessibilityService : AccessibilityService() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var bubble: MicBubble
    private val watcher = CorrectionWatcher()

    private var chordDownAt = 0L
    private var chordHeld = false
    private var latched = false
    private var pendingShortReleaseStop: Runnable? = null
    private var lastShortReleaseAt = 0L
    private var activeTriggerKey = KeyEvent.KEYCODE_UNKNOWN

    private var ctrlDown = false
    private var swallowedShift = false
    private var swallowedAlt = false

    private val refreshBubble = Runnable { updateBubble() }

    override fun onServiceConnected() {
        instance = this
        bubble = MicBubble(this) { DictationService.toggle(this) }
        // Never leave SHOW_MODE_HIDDEN stuck: it blocks keyboard binding into RustDesk and breaks typing.
        softKeyboardController.showMode = SHOW_MODE_AUTO
        DictationService.restoreIfArmed(this)
        notifyStatusChanged()
        Log.i(TAG, "Accessibility connected")
    }

    override fun onDestroy() {
        cancelPendingStop()
        runCatching { softKeyboardController.showMode = SHOW_MODE_AUTO }
        if (::bubble.isInitialized) bubble.hide()
        if (instance === this) instance = null
        notifyStatusChanged()
        super.onDestroy()
    }

    override fun onInterrupt() = Unit

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                if (!event.isPassword) {
                    val text = event.source?.let(::realEditableText) ?: event.text.joinToString("")
                    watcher.onTextChanged(event.packageName?.toString(), text)
                }
            }
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                watcher.onAppChanged(event.packageName?.toString())
                scheduleBubbleRefresh()
            }
            else -> scheduleBubbleRefresh()
        }
    }

    private fun scheduleBubbleRefresh() {
        mainHandler.removeCallbacks(refreshBubble)
        mainHandler.postDelayed(refreshBubble, 150)
    }

    private fun updateBubble() {
        if (!::bubble.isInitialized) return
        val settings = PocketFlowApp.instance.settings
        val focus = runCatching { rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) }.getOrNull()
        val pkg = focus?.packageName?.toString()
        val show = settings.bubble &&
            settings.armed &&
            focus != null &&
            focus.isEditable &&
            !focus.isPassword &&
            pkg != packageName &&
            keyboardVisible() &&
            // The PocketFlow keyboard has its own mic.
            dev.markdid.pocketflow.ime.PocketFlowImeService.editorPackage() == null
        if (show) bubble.show() else if (!DictationBus.isBusy) bubble.hide()
    }

    /**
     * The bubble follows the keyboard: a field can stay focused after its keyboard is dismissed, and the bubble
     * should go away with the keyboard. With a hardware keyboard there's no on-screen keyboard to wait for.
     */
    private fun keyboardVisible(): Boolean {
        val config = resources.configuration
        if (config.keyboard == Configuration.KEYBOARD_QWERTY &&
            config.hardKeyboardHidden == Configuration.HARDKEYBOARDHIDDEN_NO
        ) {
            return true
        }
        return runCatching { windows.any { it.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD } }.getOrDefault(true)
    }

    fun refreshBubbleState() {
        if (::bubble.isInitialized) bubble.render(DictationBus.status.value.state)
        scheduleBubbleRefresh()
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val mode = PocketFlowApp.instance.settings.hotkeyMode
        if (mode == HotkeyMode.off) return false

        // Caps Lock mode only intercepts Caps Lock, so Ctrl/Shift/letter combos keep reaching RustDesk.
        if (mode == HotkeyMode.capsLock) {
            if (event.keyCode != KeyEvent.KEYCODE_CAPS_LOCK) return false
            if (event.action == KeyEvent.ACTION_UP && chordHeld && !latched &&
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

        // Track Ctrl, but let it through: remote shortcuts need it alone.
        if (isCtrlKey(event.keyCode)) {
            ctrlDown = event.action != KeyEvent.ACTION_UP
            if (!ctrlDown) {
                swallowedShift = false
                swallowedAlt = false
            }
            return false
        }

        if (ctrlDown && shouldSwallowPartnerModifier(mode, event)) {
            val down = event.action == KeyEvent.ACTION_DOWN
            if (isShiftKey(event.keyCode)) swallowedShift = down
            if (isAltKey(event.keyCode)) swallowedAlt = down
            return true
        }

        if (event.action == KeyEvent.ACTION_UP && chordHeld && !latched &&
            activeTriggerKey != KeyEvent.KEYCODE_UNKNOWN && event.keyCode == activeTriggerKey
        ) {
            return onTriggerUp()
        }

        if (!matchesTrigger(mode, event)) return false
        return when (event.action) {
            KeyEvent.ACTION_DOWN -> onTriggerDown(event)
            KeyEvent.ACTION_UP -> true
            else -> false
        }
    }

    private fun shouldSwallowPartnerModifier(mode: HotkeyMode, event: KeyEvent): Boolean = when (mode) {
        HotkeyMode.ctrlShiftSpace -> isShiftKey(event.keyCode)
        HotkeyMode.ctrlAltSpace -> isAltKey(event.keyCode)
        else -> false
    }

    private fun onTriggerDown(event: KeyEvent): Boolean {
        if (event.repeatCount != 0) return true
        val listening = DictationBus.status.value.state == DictationState.listening

        if (listening && latched) {
            latched = false
            chordHeld = false
            activeTriggerKey = KeyEvent.KEYCODE_UNKNOWN
            cancelPendingStop()
            DictationService.stop(this)
            return true
        }

        val now = System.currentTimeMillis()
        if (listening && now - lastShortReleaseAt <= DOUBLE_TAP_MS) {
            cancelPendingStop()
            latched = true
            chordHeld = false
            activeTriggerKey = KeyEvent.KEYCODE_UNKNOWN
            DictationBus.setState(DictationState.listening, "Latched. Tap again to finish.")
            return true
        }

        if (listening) return true

        cancelPendingStop()
        chordDownAt = now
        chordHeld = true
        latched = false
        activeTriggerKey = event.keyCode
        DictationService.start(this)
        return true
    }

    private fun onTriggerUp(): Boolean {
        if (!chordHeld || latched) return true
        chordHeld = false
        val heldFor = System.currentTimeMillis() - chordDownAt
        activeTriggerKey = KeyEvent.KEYCODE_UNKNOWN

        if (heldFor >= HOLD_MS) {
            cancelPendingStop()
            DictationService.stop(this)
            return true
        }

        // Short tap: wait to see if it's the first half of a double-tap (latch).
        lastShortReleaseAt = System.currentTimeMillis()
        cancelPendingStop()
        val stop = Runnable {
            if (!latched && DictationBus.status.value.state == DictationState.listening) DictationService.stop(this)
        }
        pendingShortReleaseStop = stop
        mainHandler.postDelayed(stop, DOUBLE_TAP_MS)
        return true
    }

    private fun cancelPendingStop() {
        pendingShortReleaseStop?.let(mainHandler::removeCallbacks)
        pendingShortReleaseStop = null
    }

    private fun matchesTrigger(mode: HotkeyMode, event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_SPACE) return false
        val meta = event.metaState
        val ctrl = ctrlDown || meta and KeyEvent.META_CTRL_MASK != 0
        val shift = swallowedShift || meta and KeyEvent.META_SHIFT_MASK != 0
        val alt = swallowedAlt || meta and KeyEvent.META_ALT_MASK != 0
        return when (mode) {
            HotkeyMode.ctrlShiftSpace -> ctrl && shift && !alt
            HotkeyMode.ctrlAltSpace -> ctrl && alt
            HotkeyMode.altSpace -> alt && !ctrl
            else -> false
        }
    }

    private fun isCtrlKey(code: Int) = code == KeyEvent.KEYCODE_CTRL_LEFT || code == KeyEvent.KEYCODE_CTRL_RIGHT
    private fun isShiftKey(code: Int) = code == KeyEvent.KEYCODE_SHIFT_LEFT || code == KeyEvent.KEYCODE_SHIFT_RIGHT
    private fun isAltKey(code: Int) = code == KeyEvent.KEYCODE_ALT_LEFT || code == KeyEvent.KEYCODE_ALT_RIGHT

    companion object {
        private const val TAG = "PocketFlow"
        private const val HOLD_MS = 220L
        private const val DOUBLE_TAP_MS = 380L

        @Volatile
        private var instance: PocketFlowAccessibilityService? = null

        fun isEnabled(): Boolean = instance != null

        private fun notifyStatusChanged() = DictationBus.emit(mapOf("type" to "status"))

        fun onDictationStateChanged() {
            instance?.let { service -> service.mainHandler.post { service.refreshBubbleState() } }
        }

        fun clearSoftKeyboardOverride() {
            instance?.softKeyboardController?.showMode = SHOW_MODE_AUTO
        }

        /** Starts watching the field we just typed into. [onFinished] gets the inserted and final text. */
        fun watchForCorrections(inserted: String, onFinished: (inserted: String, fieldText: String) -> Unit) {
            val service = instance ?: return
            service.watcher.start(focusedPackage(), inserted, onFinished)
        }

        /** Ends any watch early, e.g. when the next dictation starts. */
        fun finishCorrectionWatch() {
            instance?.watcher?.finish()
        }

        fun focusedPackage(): String? {
            val service = instance ?: return null
            // The focused window is more reliable than rootInActiveWindow, which is often stale right after typing.
            runCatching {
                for (window in service.windows) {
                    if (window.isFocused || window.isActive) {
                        val pkg = window.root?.packageName?.toString()
                        if (!pkg.isNullOrBlank()) return pkg
                    }
                }
            }
            return service.rootInActiveWindow?.packageName?.toString()
        }

        /** True if RustDesk (or another remote desktop) is on screen. */
        fun isRemoteDesktopVisible(): Boolean {
            val service = instance ?: return false
            runCatching {
                for (window in service.windows) {
                    if (TextDelivery.isRemoteDesktop(window.root?.packageName?.toString().orEmpty())) return true
                    if (window.title?.toString().orEmpty().contains("rustdesk", ignoreCase = true)) return true
                }
            }
            return TextDelivery.isRemoteDesktop(focusedPackage().orEmpty())
        }

        /** Inserts at the cursor of the focused field, replacing any selection. */
        fun insertText(text: String): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false
            val focus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)?.takeIf { it.isEditable } ?: return false
            if (focus.isPassword) return false

            val current = realEditableText(focus)
            var start = focus.textSelectionStart
            var end = focus.textSelectionEnd
            if (start < 0 || end < 0 || start > current.length || end > current.length) {
                start = current.length
                end = current.length
            }
            if (start > end) start = end.also { end = start }

            val before = current.substring(0, start)
            val after = current.substring(end)
            val needsSpaceBefore = before.isNotEmpty() && !before.last().isWhitespace() && !text.first().isWhitespace()
            val needsSpaceAfter = after.isNotEmpty() && !after.first().isWhitespace() && after.first() !in ".,!?;:"
            val insertion = (if (needsSpaceBefore) " " else "") + text + (if (needsSpaceAfter) " " else "")
            val combined = before + insertion + after

            val setText = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, combined)
            }
            if (focus.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, setText)) {
                val cursor = before.length + insertion.length
                focus.performAction(
                    AccessibilityNodeInfo.ACTION_SET_SELECTION,
                    Bundle().apply {
                        putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, cursor)
                        putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, cursor)
                    },
                )
                return true
            }

            // Some fields (web views, custom editors) ignore SET_TEXT but accept a paste.
            TextDelivery.copyToClipboard(service, text)
            return focus.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        }

        /**
         * The field's text, ignoring placeholder text that some apps report as content. WhatsApp's empty compose box
         * reports "Message" as its text without flagging it as a hint, which would otherwise be kept and prefixed.
         */
        private fun realEditableText(node: AccessibilityNodeInfo): String {
            val raw = node.text?.toString().orEmpty()
            if (raw.isBlank()) return ""
            if (node.isShowingHintText) return ""
            val hint = node.hintText?.toString().orEmpty()
            if (hint.isNotBlank() && raw.equals(hint, ignoreCase = true)) return ""
            if (raw.trim().lowercase() in placeholders) return ""
            return raw
        }

        private val placeholders = setOf(
            "message", "type a message", "type message", "write a message", "send a message",
            "text message", "start messaging", "say something", "compose",
        )
    }
}
