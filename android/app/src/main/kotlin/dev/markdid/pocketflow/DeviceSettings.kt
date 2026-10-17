package dev.markdid.pocketflow

import android.content.Context

/** Floating bubble look. Names match the Dart `BubbleStyle` enum. */
@Suppress("EnumEntryName")
enum class BubbleStyle { auto, light, dark }

/** Hardware-keyboard trigger. Names match the Dart `HotkeyMode` enum. */
@Suppress("EnumEntryName")
enum class HotkeyMode { capsLock, ctrlShiftSpace, ctrlAltSpace, altSpace, off }

/**
 * Settings the native services read directly (the accessibility service checks the hotkey on every key event).
 * Pipeline settings (models, prompts, vocabulary) live on the Dart side.
 */
class DeviceSettings(context: Context) {
    private val prefs = context.getSharedPreferences("pocketflow_device", Context.MODE_PRIVATE)

    val hotkeyMode: HotkeyMode
        get() = runCatching { HotkeyMode.valueOf(prefs.getString(KEY_HOTKEY, null) ?: "") }
            .getOrDefault(HotkeyMode.capsLock)
    val bluetoothMic: Boolean get() = prefs.getBoolean(KEY_BLUETOOTH, true)
    val bubble: Boolean get() = prefs.getBoolean(KEY_BUBBLE, true)
    val bubbleStyle: BubbleStyle
        get() = runCatching { BubbleStyle.valueOf(prefs.getString(KEY_BUBBLE_STYLE, null) ?: "") }
            .getOrDefault(BubbleStyle.auto)
    val remoteDesktopTyping: Boolean get() = prefs.getBoolean(KEY_REMOTE, true)
    val walkAutoStopSeconds: Int get() = prefs.getInt(KEY_WALK_STOP, 0)

    /** Survive process death: re-arm and resume walk mode when the accessibility service reconnects. */
    var armed: Boolean
        get() = prefs.getBoolean(KEY_ARMED, false)
        set(value) = prefs.edit().putBoolean(KEY_ARMED, value).apply()
    var walkMode: Boolean
        get() = prefs.getBoolean(KEY_WALK, false)
        set(value) = prefs.edit().putBoolean(KEY_WALK, value).apply()

    fun toMap(): Map<String, Any> = mapOf(
        "hotkeyMode" to hotkeyMode.name,
        "bluetoothMic" to bluetoothMic,
        "bubble" to bubble,
        "bubbleStyle" to bubbleStyle.name,
        "remoteDesktopTyping" to remoteDesktopTyping,
        "walkAutoStopSeconds" to walkAutoStopSeconds,
    )

    fun update(map: Map<*, *>) {
        prefs.edit().apply {
            (map["hotkeyMode"] as? String)?.let { putString(KEY_HOTKEY, it) }
            (map["bluetoothMic"] as? Boolean)?.let { putBoolean(KEY_BLUETOOTH, it) }
            (map["bubble"] as? Boolean)?.let { putBoolean(KEY_BUBBLE, it) }
            (map["bubbleStyle"] as? String)?.let { putString(KEY_BUBBLE_STYLE, it) }
            (map["remoteDesktopTyping"] as? Boolean)?.let { putBoolean(KEY_REMOTE, it) }
            (map["walkAutoStopSeconds"] as? Number)?.let { putInt(KEY_WALK_STOP, it.toInt()) }
        }.apply()
    }

    private companion object {
        const val KEY_HOTKEY = "hotkey_mode"
        const val KEY_BLUETOOTH = "bluetooth_mic"
        const val KEY_BUBBLE = "bubble"
        const val KEY_BUBBLE_STYLE = "bubble_style"
        const val KEY_REMOTE = "remote_desktop_typing"
        const val KEY_WALK_STOP = "walk_auto_stop_seconds"
        const val KEY_ARMED = "armed"
        const val KEY_WALK = "walk_mode"
    }
}
