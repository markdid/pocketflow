package dev.markdid.pocketflow.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.ChannelClient
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Finished recordings wait in an outbox as `<id>_<audioMillis>.m4a` and are sent to the phone app, oldest first, over
 * a channel at `/pocketflow/recording/<id>/<audioMillis>`. Each is deleted only once the phone confirms it has it, so
 * nothing is lost when the phone is away. Paths must match the phone's `WatchListenerService`.
 */
object PhoneSync {
    private const val TAG = "PocketFlowWatch"
    private const val CAPABILITY = "pocketflow_phone"
    private const val RECORDING_PREFIX = "/pocketflow/recording/"
    const val RECEIVED_PREFIX = "/pocketflow/received/"
    const val RESULT_PREFIX = "/pocketflow/result/"
    private const val ACK_TIMEOUT_MS = 30_000L

    private val mutex = Mutex()
    private val acks = ConcurrentHashMap<String, CompletableDeferred<Unit>>()

    fun outbox(context: Context) = File(context.filesDir, "outbox").apply { mkdirs() }

    fun pending(context: Context): List<File> =
        outbox(context).listFiles { file -> file.name.endsWith(".m4a") }.orEmpty().sortedBy { it.name }

    suspend fun flush(context: Context) = mutex.withLock {
        val files = pending(context)
        if (files.isEmpty()) {
            WatchStore.setWaiting(0)
            return@withLock
        }
        val phone = findPhone(context)
        WatchStore.setWaiting(files.size, phoneReachable = phone != null)
        if (phone == null) return@withLock
        for (file in files) {
            val (id, millis) = file.nameWithoutExtension.split('_').takeIf { it.size == 2 } ?: continue
            if (!send(context, phone, file, id, millis.toLongOrNull() ?: 0)) break
        }
        WatchStore.setWaiting(pending(context).size)
    }

    /** The phone has [id] safely: drop the local copy. */
    fun acknowledge(context: Context, id: String) {
        pending(context).filter { it.name.startsWith("${id}_") }.forEach(File::delete)
        acks[id]?.complete(Unit)
        // Never step back from a result that already arrived.
        if (WatchStore.status.value.last?.phase == MemoPhase.Queued) WatchStore.advance(context, id, MemoPhase.Writing)
        WatchStore.setWaiting(pending(context).size)
    }

    suspend fun findPhone(context: Context): String? = runCatching {
        val nodes = Wearable.getCapabilityClient(context)
            .getCapability(CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .await()
            .nodes
        (nodes.firstOrNull { it.isNearby } ?: nodes.firstOrNull())?.id
    }.onFailure { Log.w(TAG, "looking for the phone failed", it) }.getOrNull()

    private suspend fun send(context: Context, node: String, file: File, id: String, millis: Long): Boolean {
        val ack = CompletableDeferred<Unit>().also { acks[id] = it }
        val channels = Wearable.getChannelClient(context)
        var channel: ChannelClient.Channel? = null
        return try {
            channel = channels.openChannel(node, "$RECORDING_PREFIX$id/$millis").await()
            channels.getOutputStream(channel).await().use { output -> file.inputStream().use { it.copyTo(output) } }
            val confirmed = withTimeoutOrNull(ACK_TIMEOUT_MS) { ack.await() } != null
            if (!confirmed) Log.w(TAG, "the phone didn't confirm $id")
            confirmed
        } catch (e: Exception) {
            Log.w(TAG, "sending $id failed", e)
            false
        } finally {
            acks.remove(id)
            channel?.let { runCatching { channels.close(it) } }
        }
    }
}
