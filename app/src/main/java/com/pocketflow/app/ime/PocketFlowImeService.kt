package com.pocketflow.app.ime

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
 * Minimal keyboard. While selected, PocketFlow can type into RustDesk via
 * InputConnection key events (forwarded like keyboard input).
 */
class PocketFlowImeService : InputMethodService() {
    private var labelView: TextView? = null
    private var lastConnection: InputConnection? = null

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

    override fun onEvaluateInputViewShown(): Boolean = true

    override fun onEvaluateFullscreenMode(): Boolean = false

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

    private fun connection(): InputConnection? =
        currentInputConnection ?: lastConnection

    private fun commitText(text: String): Boolean {
        val ic = connection() ?: return false
        return try {
            requestShowSelf(0)
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
     * Type using key events — RustDesk forwards these more reliably than commitText.
     */
    fun typeAsKeyEventsInternal(text: String): Boolean {
        val ic = connection()
        if (ic == null) {
            Log.w(TAG, "typeAsKeyEvents: no InputConnection")
            return false
        }
        requestShowSelf(0)
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
    }

    fun pasteClipboardChordInternal(): Boolean {
        val ic = connection() ?: return false
        // Ctrl+V
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
        // Also try IME helper for simple keys without meta.
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
    }
}
