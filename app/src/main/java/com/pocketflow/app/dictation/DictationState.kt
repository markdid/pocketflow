package com.pocketflow.app.dictation

enum class DictationState {
    IDLE,
    LISTENING,
    TRANSCRIBING,
    ERROR,
}

data class DictationStatus(
    val state: DictationState = DictationState.IDLE,
    val message: String = "",
    val lastTranscript: String = "",
)
