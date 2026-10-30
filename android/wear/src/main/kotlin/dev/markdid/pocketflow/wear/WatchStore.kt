package dev.markdid.pocketflow.wear

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

enum class MemoPhase {
    /** On the watch, waiting to reach the phone. */
    Queued,

    /** The phone has it and is transcribing. */
    Writing,
    Done,
    Failed,
}

/** The most recent recording, which the screen follows until the next one. */
data class LastMemo(val id: String, val phase: MemoPhase, val text: String = "")

data class WatchStatus(
    /** `SystemClock.elapsedRealtime()` when the current recording started; null when not recording. */
    val recordingSince: Long? = null,
    /** Recordings not yet on the phone. */
    val waiting: Int = 0,
    val phoneReachable: Boolean = true,
    val last: LastMemo? = null,
)

/** Process-wide watch state shared by the screen, the recorder, and the phone listener. The last memo survives restarts. */
object WatchStore {
    private val _status = MutableStateFlow(WatchStatus())
    val status: StateFlow<WatchStatus> = _status.asStateFlow()

    fun load(context: Context) {
        val prefs = prefs(context)
        val id = prefs.getString(KEY_ID, null)
        val phase = prefs.getString(KEY_PHASE, null)?.let { runCatching { MemoPhase.valueOf(it) }.getOrNull() }
        val last = if (id != null && phase != null) LastMemo(id, phase, prefs.getString(KEY_TEXT, "").orEmpty()) else null
        _status.update { it.copy(last = last, waiting = PhoneSync.pending(context).size) }
    }

    fun setRecording(since: Long?) = _status.update { it.copy(recordingSince = since) }

    fun setWaiting(count: Int, phoneReachable: Boolean = _status.value.phoneReachable) =
        _status.update { it.copy(waiting = count, phoneReachable = phoneReachable) }

    fun setLast(context: Context, memo: LastMemo) {
        _status.update { it.copy(last = memo) }
        prefs(context).edit()
            .putString(KEY_ID, memo.id)
            .putString(KEY_PHASE, memo.phase.name)
            .putString(KEY_TEXT, memo.text)
            .apply()
    }

    /** Moves the last memo on, if [id] is still the one on screen; results for older recordings only reach the phone. */
    fun advance(context: Context, id: String, phase: MemoPhase, text: String = ""): Boolean {
        if (_status.value.last?.id != id) return false
        setLast(context, LastMemo(id, phase, text))
        return true
    }

    private fun prefs(context: Context) = context.getSharedPreferences("watch", Context.MODE_PRIVATE)

    private const val KEY_ID = "last_id"
    private const val KEY_PHASE = "last_phase"
    private const val KEY_TEXT = "last_text"
}
