package dev.markdid.pocketflow.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * Records through a Bluetooth headset's microphone by opening its call-audio (SCO / LE Audio) link, the same path a
 * phone call uses. Ordinary media audio (A2DP) has no microphone channel, which is why most recorders can't use one.
 *
 * When [activate] returns true, record from `MediaRecorder.AudioSource.VOICE_COMMUNICATION`. Always call
 * [deactivate] afterwards so the headset goes back to high-quality media audio.
 */
class BluetoothMicRouter(context: Context) {
    private val appContext = context.applicationContext
    private val audioManager = appContext.getSystemService(AudioManager::class.java)
    private var active = false

    fun isAvailable(): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices.any { it.type in headsetTypes }
        } else {
            audioManager.isBluetoothScoAvailableOffCall &&
                audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS).any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
        }
    }.getOrDefault(false)

    suspend fun activate(): Boolean {
        if (!isAvailable()) return false
        active = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) activateModern() else activateLegacy()
        return active
    }

    fun deactivate() {
        if (!active) return
        active = false
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                audioManager.clearCommunicationDevice()
            } else {
                @Suppress("DEPRECATION")
                audioManager.stopBluetoothSco()
            }
            audioManager.mode = AudioManager.MODE_NORMAL
        }
    }

    private suspend fun activateModern(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        val device = audioManager.availableCommunicationDevices.firstOrNull { it.type in headsetTypes } ?: return false
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        if (!runCatching { audioManager.setCommunicationDevice(device) }.getOrDefault(false)) {
            audioManager.mode = AudioManager.MODE_NORMAL
            return false
        }
        // The link takes a moment to open; recording before then captures silence.
        val connected = withTimeoutOrNull(LINK_TIMEOUT_MS) {
            while (audioManager.communicationDevice?.id != device.id) delay(50)
            true
        } ?: false
        if (connected) delay(SETTLE_MS)
        return connected
    }

    @Suppress("DEPRECATION")
    private suspend fun activateLegacy(): Boolean {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        val connected = withTimeoutOrNull(LINK_TIMEOUT_MS) {
            suspendCancellableCoroutine { cont ->
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        val state = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1)
                        if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED && cont.isActive) {
                            runCatching { appContext.unregisterReceiver(this) }
                            cont.resume(true)
                        }
                    }
                }
                appContext.registerReceiver(receiver, IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED))
                cont.invokeOnCancellation { runCatching { appContext.unregisterReceiver(receiver) } }
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
            }
        } ?: false
        if (!connected) {
            runCatching { audioManager.stopBluetoothSco() }
            audioManager.mode = AudioManager.MODE_NORMAL
        }
        return connected
    }

    private companion object {
        const val LINK_TIMEOUT_MS = 3_000L
        const val SETTLE_MS = 250L
        val headsetTypes = buildSet {
            add(AudioDeviceInfo.TYPE_BLUETOOTH_SCO)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add(AudioDeviceInfo.TYPE_BLE_HEADSET)
        }
    }
}
