package dev.markdid.pocketflow.dictation

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** Quick Settings tile: tap to dictate into the field you were typing in, tap again to finish. */
class DictationTileService : TileService() {
    override fun onStartListening() {
        val tile = qsTile ?: return
        val state = DictationBus.status.value.state
        tile.state = if (state == DictationState.listening) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.subtitle = when (state) {
            DictationState.listening -> "Listening"
            DictationState.transcribing -> "Writing…"
            else -> null
        }
        tile.updateTile()
    }

    override fun onClick() {
        DictationService.toggle(this)
    }
}
