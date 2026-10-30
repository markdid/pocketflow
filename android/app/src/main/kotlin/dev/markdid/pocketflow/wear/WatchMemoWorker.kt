package dev.markdid.pocketflow.wear

import android.content.Context
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.Wearable
import dev.markdid.pocketflow.PocketFlowApp
import dev.markdid.pocketflow.R
import dev.markdid.pocketflow.dictation.DictationBus
import dev.markdid.pocketflow.dictation.DictationEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File

/**
 * Runs a watch recording through the memo pipeline and sends the text (or error) back to the watch. A job rather than
 * work in the listener, so a long cleanup isn't cut off when the listener unbinds, and it runs again after a crash.
 * A recording that can't be transcribed is kept in history by the pipeline, as with any memo.
 */
class WatchMemoWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val id = inputData.getString(KEY_ID) ?: return Result.failure()
        val file = File(inputData.getString(KEY_PATH) ?: return Result.failure())
        val node = inputData.getString(KEY_NODE)
        if (!file.exists()) return Result.success()

        val reply = JSONObject()
        try {
            val result = withContext(Dispatchers.Main) {
                val engine = DictationEngine(applicationContext)
                try {
                    engine.process(file.absolutePath, appId = null, memo = true, inputData.getLong(KEY_MILLIS, 0))
                } finally {
                    engine.destroy()
                }
            }
            reply.put("text", result["text"] as? String ?: "")
            (result["error"] as? String)?.let { reply.put("error", it) }
            DictationBus.emit(mapOf("type" to "history"))
        } catch (t: Throwable) {
            Log.e(TAG, "watch memo $id failed", t)
            if (runAttemptCount < 2) return Result.retry()
            reply.put("error", t.message ?: "Something went wrong.")
        }
        file.delete()
        if (node != null) {
            runCatching {
                Tasks.await(
                    Wearable.getMessageClient(applicationContext)
                        .sendMessage(node, "${WatchListenerService.RESULT_PREFIX}$id", reply.toString().toByteArray()),
                )
            }.onFailure { Log.w(TAG, "couldn't send watch memo $id back", it) }
        }
        return Result.success()
    }

    /** Only used before Android 12, where expedited work runs as a foreground service. */
    override suspend fun getForegroundInfo() = ForegroundInfo(
        NOTIFICATION_ID,
        NotificationCompat.Builder(applicationContext, PocketFlowApp.CHANNEL_SERVICE)
            .setContentTitle("PocketFlow")
            .setContentText("Writing up your watch memo…")
            .setSmallIcon(R.drawable.ic_stat_mic)
            .setSilent(true)
            .build(),
    )

    companion object {
        private const val TAG = "PocketFlowWatch"
        private const val KEY_ID = "id"
        private const val KEY_PATH = "path"
        private const val KEY_MILLIS = "audioMillis"
        private const val KEY_NODE = "node"
        private const val NOTIFICATION_ID = 46

        fun enqueue(context: Context, id: String, file: File, audioMillis: Long, node: String) {
            val request = OneTimeWorkRequestBuilder<WatchMemoWorker>()
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .setInputData(
                    workDataOf(KEY_ID to id, KEY_PATH to file.absolutePath, KEY_MILLIS to audioMillis, KEY_NODE to node),
                )
                .build()
            // A resend of a recording that's already queued (its confirmation got lost) isn't processed twice.
            WorkManager.getInstance(context).enqueueUniqueWork("watch_memo_$id", ExistingWorkPolicy.KEEP, request)
        }
    }
}
