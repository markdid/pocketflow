package dev.markdid.pocketflow

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.core.content.ContextCompat
import dev.markdid.pocketflow.accessibility.PocketFlowAccessibilityService
import dev.markdid.pocketflow.audio.BluetoothMicRouter
import dev.markdid.pocketflow.dictation.DictationBus
import dev.markdid.pocketflow.dictation.DictationService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Hosts the Flutter UI and answers its `pocketflow/app` calls about the native services. */
class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val settings get() = PocketFlowApp.instance.settings

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "pocketflow/app").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status())
                "deviceSettings" -> result.success(settings.toMap())
                "saveDeviceSettings" -> {
                    (call.arguments as? Map<*, *>)?.let(settings::update)
                    result.success(null)
                }
                "requestPermissions" -> {
                    val permissions = buildList {
                        add(Manifest.permission.RECORD_AUDIO)
                        if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS)
                    }
                    requestPermissions(permissions.toTypedArray(), REQUEST_PERMISSIONS)
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "openKeyboardSettings" -> {
                    startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
                    result.success(null)
                }
                "setArmed" -> {
                    if (call.argument<Boolean>("value") == true) {
                        DictationService.arm(this)
                    } else {
                        DictationService.disarm(this)
                    }
                    result.success(null)
                }
                "setWalkMode" -> {
                    DictationService.setWalkMode(this, call.argument<Boolean>("value") == true)
                    result.success(null)
                }
                "toggleDictation" -> {
                    DictationService.toggle(this)
                    result.success(null)
                }
                "toggleRecording" -> {
                    DictationService.toggleRecording(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "pocketflow/events").setStreamHandler(object : EventChannel.StreamHandler {
            private var jobs: List<Job> = emptyList()

            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                jobs = listOf(
                    scope.launch {
                        DictationBus.status.collect { sink.success(mapOf("type" to "status")) }
                    },
                    scope.launch { DictationBus.events.collect(sink::success) },
                    scope.launch {
                        while (true) {
                            val level = DictationService.levelSource
                            if (level == null) {
                                delay(250)
                            } else {
                                sink.success(mapOf("type" to "level", "value" to level().toDouble()))
                                delay(50)
                            }
                        }
                    },
                )
            }

            override fun onCancel(arguments: Any?) {
                jobs.forEach(Job::cancel)
                jobs = emptyList()
            }
        })
    }

    private fun status(): Map<String, Any> {
        val bus = DictationBus.status.value
        return mapOf(
            "micPermission" to granted(Manifest.permission.RECORD_AUDIO),
            "notificationPermission" to (Build.VERSION.SDK_INT < 33 || granted(Manifest.permission.POST_NOTIFICATIONS)),
            "accessibilityEnabled" to PocketFlowAccessibilityService.isEnabled(),
            "keyboardEnabled" to getSystemService(InputMethodManager::class.java).enabledInputMethodList
                .any { it.packageName == packageName },
            "secureSettingsGranted" to granted(Manifest.permission.WRITE_SECURE_SETTINGS),
            "armed" to settings.armed,
            "walkMode" to settings.walkMode,
            "bluetoothMicAvailable" to BluetoothMicRouter(this).isAvailable(),
            "state" to bus.state.name,
            "message" to bus.message,
            "audioOnly" to bus.audioOnly,
        )
    }

    private fun granted(permission: String) =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private companion object {
        const val REQUEST_PERMISSIONS = 1
    }
}
