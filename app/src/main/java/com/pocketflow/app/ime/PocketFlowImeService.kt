package com.pocketflow.app.ime

import android.content.res.Configuration
import android.inputmethodservice.InputMethodService
import android.os.SystemClock
import android.util.Log
import android.view.InputDevice
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.FrameLayout
import android.widget.TextView
import com.pocketflow.app.dictation.DictationBus
import com.pocketflow.app.dictation.DictationState

/**
 * Minimal keyboard. Stays selected so we can type into RustDesk char-by-char
 * (the path that previously worked). Soft-keyboard chrome stays hidden with a
 * HW keyboard except briefly while injecting.
 */
class PocketFlowImeService : InputMethodService() {
    private var labelView: TextView? = null
    private var lastConnection: InputConnection? = null

    @Volatile
    private var forceShowForTyping = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        DictationBus.textCommitter = { text -> typeAsKeyEvents(text) || commitText(text) }
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
            DictationBus.textCommitter = null
        }
        labelView = null
        lastConnection = null
        super.onDestroy()
    }

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        lastConnection = currentInputConnection
        Log.i(TAG, "onStartInput ic=${lastConnection != null} pkg=${attribute?.packageName}")
    }

    override fun onFinishInput() {
        lastConnection = null
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

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean = false

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean = false

    override fun onCreateInputView(): View {
        val pad = (12 * resources.displayMetrics.density).toInt()
        return TextView(this).apply {
            labelView = this
            text = "PocketFlow · hold Caps Lock"
            setPadding(pad, pad, pad, pad)
            textSize = 14f
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            )
        }
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        lastConnection = currentInputConnection
        labelView?.text = when (DictationBus.status.value.state) {
            DictationState.LISTENING -> "PocketFlow · Listening…"
            DictationState.TRANSCRIBING -> "PocketFlow · Transcribing…"
            else -> "PocketFlow · hold Caps Lock"
        }
    }

    private fun hasHardwareKeyboard(): Boolean {
        val c = resources.configuration
        return c.keyboard == Configuration.KEYBOARD_QWERTY &&
            c.hardKeyboardHidden != Configuration.HARDKEYBOARDHIDDEN_YES
    }

    private fun connection(): InputConnection? =
        currentInputConnection ?: lastConnection

    private fun commitText(text: String): Boolean {
        val ic = connection() ?: return false
        return try {
            ic.beginBatchEdit()
            ic.commitText(text, 1)
            ic.endBatchEdit()
            Log.i(TAG, "commitText ok (${text.length})")
            true
        } catch (t: Throwable) {
            Log.w(TAG, "commitText failed", t)
            false
        }
    }

    /**
     * Char-by-char key events — restored from the last known-working build.
     * Do not one-shot commitText the whole string; that stopped reaching RustDesk.
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
            Log.i(TAG, "typeAsKeyEvents IC ok after ${tries * 40}ms len=${text.length}")

            val kcm = KeyCharacterMap.load(KeyCharacterMap.VIRTUAL_KEYBOARD)
            var any = false
            for (ch in text) {
                when (ch) {
                    '\n' -> {
                        sendDownUp(ic, KeyEvent.KEYCODE_ENTER, 0)
                        any = true
                    }
                    '\t' -> {
                        sendDownUp(ic, KeyEvent.KEYCODE_TAB, 0)
                        any = true
                    }
                    else -> {
                        val events = kcm.getEvents(charArrayOf(ch))
                        if (events == null) {
                            ic.commitText(ch.toString(), 1)
                            any = true
                        } else {
                            for (ev in events) {
                                ic.sendKeyEvent(ev)
                                any = true
                            }
                        }
                    }
                }
                SystemClock.sleep(4)
            }
            Log.i(TAG, "typeAsKeyEvents ok=$any len=${text.length}")
            return any
        } finally {
            forceShowForTyping = false
            requestHideSelf(0)
        }
    }

    fun pasteClipboardChordInternal(): Boolean {
        val ic = connection() ?: return false
        sendDownUp(ic, KeyEvent.KEYCODE_V, KeyEvent.META_CTRL_ON)
        Log.i(TAG, "sent Ctrl+V via IME")
        return true
    }

    private fun sendDownUp(ic: InputConnection, keyCode: Int, meta: Int) {
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
        if (meta == 0) {
            sendDownUpKeyEvents(keyCode)
        }
    }

    companion object {
        private const val TAG = "PocketFlow"

        @Volatile
        private var instance: PocketFlowImeService? = null

        fun isActive(): Boolean =
            instance?.connection() != null

        fun commitTextIfActive(text: String): Boolean {
            val ime = instance ?: return false
            return ime.commitText(text)
        }

        fun typeAsKeyEvents(text: String): Boolean {
            val ime = instance ?: return false
            return ime.typeAsKeyEventsInternal(text)
        }

        fun pasteClipboardChord(): Boolean {
            val ime = instance ?: return false
            return ime.pasteClipboardChordInternal()
        }

        fun hideInputUi() {
            instance?.requestHideSelf(0)
        }
    }
}
