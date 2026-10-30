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
import dev.markdid.pocketflow.PocketFlowApp
import dev.markdid.pocketflow.R
import dev.markdid.pocketflow.dictation.DictationBus
import dev.markdid.pocketflow.dictation.DictationEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
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

        var text = ""
        var error: String? = null
        try {
            val result = withContext(Dispatchers.Main) {
                val engine = DictationEngine(applicationContext)
                try {
                    // Only the text matters from the watch; failed recordings are still kept to retry.
                    engine.process(
                        file.absolutePath,
                        appId = null,
                        memo = true,
                        audioMillis = inputData.getLong(KEY_MILLIS, 0),
                        keepAudio = false,
                    )
                } finally {
                    engine.destroy()
                }
            }
            text = result["text"] as? String ?: ""
            error = result["error"] as? String
            DictationBus.emit(mapOf("type" to "history"))
        } catch (t: Throwable) {
            Log.e(TAG, "watch memo $id failed", t)
            if (runAttemptCount < 2) return Result.retry()
            error = t.message ?: "Something went wrong."
        }
        file.delete()
        if (node != null) WatchRemote.result(applicationContext, node, id, text, error)
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
