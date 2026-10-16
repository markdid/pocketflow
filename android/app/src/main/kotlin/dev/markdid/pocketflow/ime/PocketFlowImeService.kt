package dev.markdid.pocketflow.ime

import android.content.res.Configuration
import android.graphics.drawable.GradientDrawable
import android.inputmethodservice.InputMethodService
import android.os.SystemClock
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.InputDevice
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import dev.markdid.pocketflow.dictation.DictationBus
import dev.markdid.pocketflow.dictation.DictationService
import dev.markdid.pocketflow.dictation.DictationState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Voice keyboard: a big mic button that dictates straight into the field, plus a key to switch back to your usual
 * keyboard.
 *
 * It also carries the remote-desktop path: RustDesk only reacts to real key events, so text is typed into it
 * character by character from here. With a hardware keyboard attached the on-screen panel stays hidden, except
 * briefly while typing.
 */
class PocketFlowImeService : InputMethodService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var statusView: TextView? = null
    private var micButton: ImageButton? = null
    private var lastConnection: InputConnection? = null
    private var editorPackage: String? = null

    @Volatile
    private var forceShowForTyping = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        scope.launch { DictationBus.status.collect { render() } }
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        scope.cancel()
        statusView = null
        micButton = null
        lastConnection = null
        super.onDestroy()
    }

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        lastConnection = currentInputConnection
        editorPackage = attribute?.packageName
    }

    override fun onFinishInput() {
        lastConnection = null
        editorPackage = null
        super.onFinishInput()
    }

    override fun onEvaluateInputViewShown(): Boolean {
        if (forceShowForTyping) return true
        if (hasHardwareKeyboard()) return false
        return super.onEvaluateInputViewShown()
    }

    override fun onShowInputRequested(flags: Int, configChange: Boolean): Boolean {
        if (forceShowForTyping) return true
        if (hasHardwareKeyboard()) return false
        return super.onShowInputRequested(flags, configChange)
    }

    override fun onEvaluateFullscreenMode(): Boolean = false

    // Hardware keys pass straight through to the app (RustDesk needs Ctrl shortcuts).
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean = false

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean = false

    override fun onCreateInputView(): View {
        val dp = { value: Int -> TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt() }
        val status = TextView(this).apply {
            gravity = Gravity.CENTER
            textSize = 14f
            setPadding(0, dp(12), 0, dp(8))
        }
        val mic = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFF3F51B5.toInt())
            }
            contentDescription = "Dictate"
            setOnClickListener { DictationService.toggle(this@PocketFlowImeService) }
        }
        val switchKey = keyButton(android.R.drawable.ic_menu_sort_alphabetically, "Switch keyboard") {
            if (!switchToNextInputMethod(false)) {
                getSystemService(android.view.inputmethod.InputMethodManager::class.java).showInputMethodPicker()
            }
        }
        val backspace = keyButton(android.R.drawable.ic_input_delete, "Delete") {
            connection()?.let { sendDownUp(it, KeyEvent.KEYCODE_DEL, 0) }
        }
        val enter = keyButton(android.R.drawable.ic_menu_send, "Enter") {
            connection()?.let { sendDownUp(it, KeyEvent.KEYCODE_ENTER, 0) }
        }
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), 0, dp(16), dp(16))
            addView(switchKey, LinearLayout.LayoutParams(0, dp(48), 1f))
            addView(mic, LinearLayout.LayoutParams(dp(88), dp(88)))
            addView(backspace, LinearLayout.LayoutParams(0, dp(48), 1f))
            addView(enter, LinearLayout.LayoutParams(0, dp(48), 1f))
        }
        statusView = status
        micButton = mic
        render()
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(status)
            addView(row)
        }
    }

    private fun keyButton(icon: Int, description: String, onClick: () -> Unit) = ImageButton(this).apply {
        setImageResource(icon)
        setBackgroundColor(0)
        contentDescription = description
        setOnClickListener { onClick() }
    }

    private fun render() {
        val status = DictationBus.status.value
        statusView?.text = when (status.state) {
            DictationState.listening -> "Listening… tap to finish"
            DictationState.transcribing -> "Writing…"
            DictationState.error -> status.message
            DictationState.idle -> "Tap the mic and speak"
        }
        micButton?.alpha = if (status.state == DictationState.transcribing) 0.5f else 1f
    }

    private fun hasHardwareKeyboard(): Boolean {
        val c = resources.configuration
        return c.keyboard == Configuration.KEYBOARD_QWERTY && c.hardKeyboardHidden != Configuration.HARDKEYBOARDHIDDEN_YES
    }

    private fun connection(): InputConnection? = currentInputConnection ?: lastConnection

    private fun commitText(text: String): Boolean {
        val ic = connection() ?: return false
        return try {
            ic.beginBatchEdit()
            ic.commitText(text, 1)
            ic.endBatchEdit()
            true
        } catch (t: Throwable) {
            Log.w(TAG, "commitText failed", t)
            false
        }
    }

    /**
     * Char-by-char key events. Don't one-shot commitText the whole string for remote desktops; that reports success
     * without reaching RustDesk.
     */
    fun typeAsKeyEventsInternal(text: String): Boolean {
        forceShowForTyping = true
        try {
            requestShowSelf(0)
            updateInputViewShown()
            var ic: InputConnection? = connection()
            var tries = 0
            while (ic == null && tries < 25) {
                SystemClock.sleep(40)
                requestShowSelf(0)
                ic = connection()
                tries++
            }
            if (ic == null) {
                Log.w(TAG, "typeAsKeyEvents: no InputConnection")
                return false
            }

            val kcm = KeyCharacterMap.load(KeyCharacterMap.VIRTUAL_KEYBOARD)
            var any = false
            for (ch in text) {
                when (ch) {
                    // Also sent via sendDownUpKeyEvents, as in the build that last worked with RustDesk.
                    '\n' -> sendDownUp(ic, KeyEvent.KEYCODE_ENTER, 0, viaService = true)
                    '\t' -> sendDownUp(ic, KeyEvent.KEYCODE_TAB, 0, viaService = true)
                    else -> {
                        val events = kcm.getEvents(charArrayOf(ch))
                        if (events == null) ic.commitText(ch.toString(), 1) else events.forEach(ic::sendKeyEvent)
                    }
                }
                any = true
                SystemClock.sleep(4)
            }
            return any
        } finally {
            forceShowForTyping = false
            if (hasHardwareKeyboard()) requestHideSelf(0)
        }
    }

    fun pasteClipboardChordInternal(): Boolean {
        val ic = connection() ?: return false
        sendDownUp(ic, KeyEvent.KEYCODE_V, KeyEvent.META_CTRL_ON)
        return true
    }

    private fun sendDownUp(ic: InputConnection, keyCode: Int, meta: Int, viaService: Boolean = false) {
        val now = SystemClock.uptimeMillis()
        val down = KeyEvent(
            now, now, KeyEvent.ACTION_DOWN, keyCode, 0, meta,
            KeyCharacterMap.VIRTUAL_KEYBOARD, 0, 0, InputDevice.SOURCE_KEYBOARD,
        )
        val up = KeyEvent(
            now, now, KeyEvent.ACTION_UP, keyCode, 0, meta,
            KeyCharacterMap.VIRTUAL_KEYBOARD, 0, 0, InputDevice.SOURCE_KEYBOARD,
        )
        ic.sendKeyEvent(down)
        ic.sendKeyEvent(up)
        if (viaService && meta == 0) sendDownUpKeyEvents(keyCode)
    }

    companion object {
        private const val TAG = "PocketFlow"

        @Volatile
        private var instance: PocketFlowImeService? = null

        /** Package of the field the PocketFlow keyboard is attached to, while it is the active keyboard. */
        fun editorPackage(): String? = instance?.takeIf { it.connection() != null }?.editorPackage

        fun commitTextIfActive(text: String): Boolean {
            val ime = instance ?: return false
            if (ime.connection() == null) return false
            return ime.commitText(text)
        }

        fun typeAsKeyEvents(text: String): Boolean = instance?.typeAsKeyEventsInternal(text) ?: false

        fun pasteClipboardChord(): Boolean = instance?.pasteClipboardChordInternal() ?: false

        fun hideInputUi() {
            instance?.requestHideSelf(0)
        }
    }
}
