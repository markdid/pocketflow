package com.pocketflow.app.dictation

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Process-wide dictation status + a hook the IME registers so transcribed text
 * can be committed through the active input connection (best path for RustDesk).
 */
object DictationBus {
    private val _status = MutableStateFlow(DictationStatus())
    val status: StateFlow<DictationStatus> = _status.asStateFlow()

    private val _armed = MutableStateFlow(false)
    val armed: StateFlow<Boolean> = _armed.asStateFlow()

    private val _accessibilityConnected = MutableStateFlow(false)
    val accessibilityConnected: StateFlow<Boolean> = _accessibilityConnected.asStateFlow()

    @Volatile
    var textCommitter: ((String) -> Boolean)? = null

    fun setArmed(value: Boolean) {
        _armed.value = value
    }

    fun setAccessibilityConnected(value: Boolean) {
        _accessibilityConnected.value = value
    }

    fun update(transform: (DictationStatus) -> DictationStatus) {
        _status.update(transform)
    }

    fun setState(state: DictationState, message: String = "", lastTranscript: String? = null) {
        _status.update {
            it.copy(
                state = state,
                message = message,
                lastTranscript = lastTranscript ?: it.lastTranscript,
            )
        }
    }
}
