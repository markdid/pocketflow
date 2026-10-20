package dev.markdid.pocketflow.dictation

import android.app.Service
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.ParcelFileDescriptor
import android.os.RemoteException
import android.util.Log
import androidx.core.os.BundleCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Lets Lumon (the companion app for the Rokid glasses, which own their mic) hand over a voice note to save as a
 * memo. Bind explicitly and send a [Message] whose data has `audio` (a read-only [ParcelFileDescriptor]), `name` (a
 * file name with the right extension), `audioMillis`, and `voiceCommand` (true when the recording starts with "take
 * a note" or similar, which is dropped). The reply's data has `text`, or `error` and `saved`.
 *
 * Binding rather than starting keeps this process alive while it works without a foreground service, which a
 * background caller couldn't start.
 */
class AudioImportService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var engine: DictationEngine? = null
    private val messenger = Messenger(
        Handler(Looper.getMainLooper()) { message ->
            handle(message)
            true
        },
    )

    override fun onBind(intent: Intent?): IBinder = messenger.binder

    private fun handle(message: Message) {
        val replyTo = message.replyTo ?: return
        if (!isAllowed(message.sendingUid)) {
            Log.w(TAG, "refused an import from uid ${message.sendingUid}")
            reply(replyTo, Bundle().apply { putString("error", "PocketFlow doesn't accept recordings from this app.") })
            return
        }
        // The message is recycled once this returns, so read everything now.
        val data = message.data
        val audio = BundleCompat.getParcelable(data, "audio", ParcelFileDescriptor::class.java)
        val extension = data.getString("name").orEmpty().substringAfterLast('.', "").filter(Char::isLetterOrDigit)
        val audioMillis = data.getLong("audioMillis")
        val voiceCommand = data.getBoolean("voiceCommand")
        if (audio == null) {
            reply(replyTo, Bundle().apply { putString("error", "No recording was attached.") })
            return
        }

        scope.launch {
            val file = File(cacheDir, "import_${System.currentTimeMillis()}.${extension.ifEmpty { "wav" }}")
            val result = Bundle()
            try {
                withContext(Dispatchers.IO) {
                    ParcelFileDescriptor.AutoCloseInputStream(audio).use { input ->
                        file.outputStream().use(input::copyTo)
                    }
                }
                val engine = engine ?: DictationEngine(this@AudioImportService).also { engine = it }
                val processed = engine.process(file.absolutePath, appId = null, memo = true, audioMillis, voiceCommand)
                val text = processed["text"] as? String
                val saved = processed["saved"] == true
                result.putString("text", text)
                result.putString("error", processed["error"] as? String)
                result.putBoolean("saved", saved)
                if (!text.isNullOrEmpty() || saved) DictationBus.emit(mapOf("type" to "history"))
                Log.i(TAG, "imported a ${audioMillis} ms memo: ${if (text.isNullOrEmpty()) "no text" else "saved"}")
            } catch (t: Throwable) {
                Log.e(TAG, "import failed", t)
                result.putString("error", t.message ?: "Something went wrong.")
            } finally {
                file.delete()
            }
            reply(replyTo, result)
        }
    }

    private fun isAllowed(uid: Int): Boolean = packageManager.getPackagesForUid(uid)?.any(ALLOWED_PACKAGES::contains) == true

    private fun reply(to: Messenger, data: Bundle) {
        try {
            to.send(Message.obtain().apply { this.data = data })
        } catch (e: RemoteException) {
            Log.w(TAG, "the caller went away before the reply", e)
        }
    }

    override fun onDestroy() {
        scope.cancel()
        engine?.destroy()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "PocketFlowImport"

        /** Lumon, the glasses companion app. */
        private val ALLOWED_PACKAGES = setOf("com.rokidsync.rokid_sync")
    }
}
