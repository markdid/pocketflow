package dev.markdid.pocketflow.dictation

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Names match the Dart `DictationState` enum. */
@Suppress("EnumEntryName")
enum class DictationState { idle, listening, transcribing, error }

data class DictationStatus(
    val state: DictationState = DictationState.idle,
    val message: String = "",
    val armed: Boolean = false,
    val walkMode: Boolean = false,
)

/** Process-wide dictation status shared by the service, accessibility service, keyboard, tile, and UI. */
object DictationBus {
    private val _status = MutableStateFlow(DictationStatus())
    val status: StateFlow<DictationStatus> = _status.asStateFlow()

    /** One-off events for the Flutter UI: a dictation finished (`history`) or words were learned (`learned`). */
    private val _events = MutableSharedFlow<Map<String, Any?>>(
        extraBufferCapacity = 16,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val events: SharedFlow<Map<String, Any?>> = _events.asSharedFlow()

    val isBusy: Boolean
        get() = status.value.state == DictationState.listening || status.value.state == DictationState.transcribing

    fun setState(state: DictationState, message: String = "") =
        _status.update { it.copy(state = state, message = message) }

    fun setArmed(armed: Boolean, walkMode: Boolean) =
        _status.update { it.copy(armed = armed, walkMode = walkMode) }

    fun emit(event: Map<String, Any?>) {
        _events.tryEmit(event)
    }
}
