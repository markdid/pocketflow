package dev.markdid.pocketflow.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.ConcurrentHashMap

/**
 * With headphones connected to the phone, a memo is recorded there through the headset mic (so the wrist can stay
 * down), and the phone says "Listening" in the earbuds. The watch only starts and stops it. Paths must match the
 * phone's `WatchRemote`.
 */
object PhoneRemote {
    private const val TAG = "PocketFlowWatch"
    private const val PREFIX = "/pocketflow/remote/"
    const val LISTENING = "${PREFIX}listening/"
    const val UNAVAILABLE = "${PREFIX}unavailable/"
    const val STOPPED = "${PREFIX}stopped/"

    /** Covers opening the headset link and saying "Listening". */
    private const val ANSWER_TIMEOUT_MS = 8_000L

    private val answers = ConcurrentHashMap<String, CompletableDeferred<Boolean>>()

    @Volatile
    private var phone: String? = null

    /** True once the phone is recording [id]; false if it has no headphones, is busy, or doesn't answer in time. */
    suspend fun start(context: Context, id: String): Boolean {
        val node = PhoneSync.findPhone(context) ?: return false.also { Log.i(TAG, "no phone in reach for $id") }
        val answer = CompletableDeferred<Boolean>().also { answers[id] = it }
        return try {
            Wearable.getMessageClient(context).sendMessage(node, "${PREFIX}start/$id", null).await()
            val listening = withTimeoutOrNull(ANSWER_TIMEOUT_MS) { answer.await() }
            // Too late: the watch is recording it, so the phone mustn't as well.
            if (listening == null) send(context, node, "${PREFIX}cancel/$id")
            if (listening == true) phone = node
            Log.i(TAG, "phone headset for $id: ${listening ?: "no answer"}")
            listening == true
        } catch (e: Exception) {
            Log.w(TAG, "asking the phone to record failed", e)
            false
        } finally {
            answers.remove(id)
        }
    }

    fun answer(id: String, listening: Boolean) {
        answers[id]?.complete(listening)
    }

    fun stop(context: Context, id: String) = phone?.let { send(context, it, "${PREFIX}stop/$id") }

    /** The watch stopped before the phone answered and kept its own recording. */
    fun cancel(context: Context, id: String) = phone?.let { send(context, it, "${PREFIX}cancel/$id") }

    private fun send(context: Context, node: String, path: String) {
        Wearable.getMessageClient(context).sendMessage(node, path, null)
            .addOnFailureListener { Log.w(TAG, "couldn't send $path to the phone", it) }
    }
}
