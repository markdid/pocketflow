package dev.markdid.pocketflow.wear

import android.util.Log
import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.runBlocking
import org.json.JSONObject

/** Confirmations and finished memos from the phone, and a nudge to send queued recordings when it comes back. */
class PhoneListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        val path = event.path
        when {
            path.startsWith(PhoneSync.RECEIVED_PREFIX) ->
                PhoneSync.acknowledge(this, path.removePrefix(PhoneSync.RECEIVED_PREFIX))
            path.startsWith(PhoneSync.RESULT_PREFIX) -> {
                val id = path.removePrefix(PhoneSync.RESULT_PREFIX)
                val result = runCatching { JSONObject(String(event.data)) }.getOrElse { JSONObject() }
                val error = result.optString("error")
                val shown = if (error.isNotEmpty()) {
                    WatchStore.advance(this, id, MemoPhase.Failed, error)
                } else {
                    WatchStore.advance(this, id, MemoPhase.Done, result.optString("text"))
                }
                if (shown) WatchApp.buzz(this, if (error.isEmpty()) longArrayOf(0, 30) else longArrayOf(0, 60, 80, 60))
                Log.i(TAG, "memo $id came back${if (error.isEmpty()) "" else " with an error"}")
            }
        }
    }

    // Runs on a background thread while the service is bound, so sending here finishes before it unbinds.
    override fun onCapabilityChanged(info: CapabilityInfo) {
        if (info.nodes.isNotEmpty()) runBlocking { PhoneSync.flush(this@PhoneListenerService) }
    }

    private companion object {
        const val TAG = "PocketFlowWatch"
    }
}
