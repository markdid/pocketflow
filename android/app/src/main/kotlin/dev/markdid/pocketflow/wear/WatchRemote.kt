package dev.markdid.pocketflow.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject

/**
 * Messages to the PocketFlow watch app. When headphones are connected to the phone, the watch's record button records
 * here through the headset instead (`/pocketflow/remote/start/<id>`), and this reports how it's going. Paths must
 * match the watch's `PhoneRemote` and `PhoneSync`.
 */
object WatchRemote {
    private const val TAG = "PocketFlowWatch"
    const val PREFIX = "/pocketflow/remote/"
    const val START = "${PREFIX}start/"
    const val STOP = "${PREFIX}stop/"
    const val CANCEL = "${PREFIX}cancel/"

    /** A memo started from the watch [node], identified by the watch's [id]. */
    data class Session(val id: String, val node: String)

    /** The headset mic is open and recording. */
    fun listening(context: Context, session: Session) = send(context, session.node, "${PREFIX}listening/${session.id}")

    /** No headphones, or the phone is busy: the watch records with its own mic. */
    fun unavailable(context: Context, node: String, id: String) = send(context, node, "${PREFIX}unavailable/$id")

    /** Recording finished (from the watch, the earbud, or silence) and is being written up. */
    fun stopped(context: Context, session: Session) = send(context, session.node, "${PREFIX}stopped/${session.id}")

    fun result(context: Context, node: String, id: String, text: String, error: String? = null) {
        val reply = JSONObject().put("text", text)
        if (error != null) reply.put("error", error)
        send(context, node, "/pocketflow/result/$id", reply.toString().toByteArray())
    }

    private fun send(context: Context, node: String, path: String, data: ByteArray? = null) {
        Wearable.getMessageClient(context).sendMessage(node, path, data)
            .addOnFailureListener { Log.w(TAG, "couldn't send $path to the watch", it) }
    }
}
