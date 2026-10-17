package dev.markdid.pocketflow.dictation

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Headless Flutter engine running `dictationEngineMain` (lib/main.dart). Native code records and delivers; the shared
 * Dart pipeline transcribes, cleans up, learns, and writes history. Create and call on the main thread.
 */
class DictationEngine(context: Context) {
    private val engine: FlutterEngine
    private val channel: MethodChannel
    private val ready = CompletableDeferred<Unit>()

    init {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context.applicationContext)
        loader.ensureInitializationComplete(context.applicationContext, null)
        engine = FlutterEngine(context.applicationContext)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "pocketflow/engine")
        channel.setMethodCallHandler { call, result ->
            if (call.method == "ready") {
                ready.complete(Unit)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "dictationEngineMain"),
        )
    }

    /** Returns `text` (empty if nothing was said), and optionally `warning` or `error`. */
    suspend fun process(path: String, appId: String?, memo: Boolean, audioMillis: Long): Map<*, *> {
        val args = mapOf(
            "path" to path,
            "appId" to appId,
            "mode" to if (memo) "memo" else "dictation",
            "audioMillis" to audioMillis.toInt(),
        )
        return invoke("process", args) as? Map<*, *> ?: emptyMap<String, Any>()
    }

    /** Opens the API connection while the user is still speaking. */
    suspend fun warmUp() {
        invoke("warmUp", null)
    }

    /** Returns what was learned, as maps with `heard`, `term`, and `addedRule`. */
    suspend fun learn(inserted: String, fieldText: String): List<Map<*, *>> =
        (invoke("learn", mapOf("inserted" to inserted, "fieldText" to fieldText)) as? List<*>)
            ?.filterIsInstance<Map<*, *>>()
            .orEmpty()

    private suspend fun invoke(method: String, args: Any?): Any? {
        ready.await()
        return suspendCancellableCoroutine { cont ->
            channel.invokeMethod(method, args, object : MethodChannel.Result {
                override fun success(result: Any?) = cont.resume(result)
                override fun error(code: String, message: String?, details: Any?) =
                    cont.resumeWithException(IllegalStateException(message ?: code))
                override fun notImplemented() = cont.resumeWithException(IllegalStateException("$method missing"))
            })
        }
    }

    fun destroy() = engine.destroy()
}
