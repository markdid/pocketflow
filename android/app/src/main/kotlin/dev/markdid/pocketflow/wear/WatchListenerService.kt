package dev.markdid.pocketflow.wear

import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.ChannelClient
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import java.io.File

/**
 * Receives recordings from the PocketFlow watch app. Each arrives on a channel at
 * `/pocketflow/recording/<id>/<audioMillis>`; once the file is safely in the inbox the watch is told it can delete its
 * copy, and [WatchMemoWorker] turns it into a memo. Paths must match the watch's `PhoneSync`.
 */
class WatchListenerService : WearableListenerService() {
    // Called on a background thread, and the service stays bound until it returns, so blocking here is intended.
    override fun onChannelOpened(channel: ChannelClient.Channel) {
        if (!channel.path.startsWith(RECORDING_PREFIX)) return
        val parts = channel.path.removePrefix(RECORDING_PREFIX).split('/')
        val id = parts.getOrNull(0).orEmpty().filter(Char::isLetterOrDigit)
        val audioMillis = parts.getOrNull(1)?.toLongOrNull() ?: 0
        val channels = Wearable.getChannelClient(this)
        if (id.isEmpty()) {
            channels.close(channel)
            return
        }
        val inbox = File(filesDir, INBOX).apply { mkdirs() }
        val file = File(inbox, "$id.m4a")
        try {
            val partial = File(inbox, "$id.part")
            Tasks.await(channels.getInputStream(channel)).use { input -> partial.outputStream().use(input::copyTo) }
            if (!partial.renameTo(file)) error("couldn't move $partial into the inbox")
        } catch (e: Exception) {
            // The watch keeps its copy and sends it again.
            Log.w(TAG, "receiving watch recording $id failed", e)
            return
        } finally {
            channels.close(channel)
        }
        Log.i(TAG, "received a $audioMillis ms watch recording ($id, ${file.length()} bytes)")
        runCatching {
            Tasks.await(Wearable.getMessageClient(this).sendMessage(channel.nodeId, "$RECEIVED_PREFIX$id", null))
        }.onFailure { Log.w(TAG, "couldn't confirm watch recording $id", it) }
        WatchMemoWorker.enqueue(this, id, file, audioMillis, channel.nodeId)
    }

    companion object {
        private const val TAG = "PocketFlowWatch"
        const val INBOX = "watch_inbox"
        private const val RECORDING_PREFIX = "/pocketflow/recording/"
        private const val RECEIVED_PREFIX = "/pocketflow/received/"
        const val RESULT_PREFIX = "/pocketflow/result/"
    }
}
