package dev.markdid.pocketflow.input

import android.util.Log
import android.view.KeyEvent

/**
 * Requests shell-level `input keycombination` via a Mac-side helper that watches logcat
 * ([tools/pocketflow-keyinject.sh]).
 *
 * Apps lack INJECT_EVENTS. IME Meta+V only pastes the *phone* clipboard (so Cmd+V after dictation re-pastes the
 * transcript; Cmd+C never copies the Mac selection). Shell injection sends real Meta chords into RustDesk → Mac.
 */
object HostKeyInjector {
    private const val TAG = "PocketFlow"
    private const val INJECT_TAG = "PocketFlowInject"

    fun injectMetaShortcut(keyCode: Int, shift: Boolean): Boolean {
        val codes = buildList {
            add(KeyEvent.KEYCODE_META_LEFT)
            if (shift) add(KeyEvent.KEYCODE_SHIFT_LEFT)
            add(keyCode)
        }
        // Fire-and-forget: the helper runs `input keycombination` as shell.
        val payload = "keycombination ${codes.joinToString(" ")}"
        Log.i(INJECT_TAG, payload)
        Log.i(TAG, "HostKeyInjector requested $payload")
        return true
    }
}
