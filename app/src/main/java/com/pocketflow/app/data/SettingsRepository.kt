package com.pocketflow.app.data

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class HotkeyMode {
    /** Caps Lock — ideal for RustDesk (single key, no Alt) */
    CAPS_LOCK,

    /** Ctrl+Shift+Space — solid RustDesk chord without Alt */
    CTRL_SHIFT_SPACE,

    /** Ctrl+Alt+Space — Alt is swallowed so RustDesk shouldn't see it */
    CTRL_ALT_SPACE,

    /** Alt+Space — conflicts with RustDesk Alt gestures */
    ALT_SPACE,

    /** Fn+Alt — usually unavailable on BT boards */
    FN_ALT,

    /** Prefer Caps Lock, then Ctrl+Shift+Space, then others */
    ALL,
}

class SettingsRepository(context: Context) {
    private val appContext = context.applicationContext

    private val prefs: SharedPreferences = run {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        EncryptedSharedPreferences.create(
            "pocketflow_secure",
            masterKeyAlias,
            appContext,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    private val _apiKey = MutableStateFlow(prefs.getString(KEY_API, "").orEmpty())
    val apiKey: StateFlow<String> = _apiKey.asStateFlow()

    private val _hotkeyMode = MutableStateFlow(readHotkeyMode())
    val hotkeyMode: StateFlow<HotkeyMode> = _hotkeyMode.asStateFlow()

    private val _language = MutableStateFlow(prefs.getString(KEY_LANG, "en").orEmpty())
    val language: StateFlow<String> = _language.asStateFlow()

    fun setApiKey(value: String) {
        prefs.edit().putString(KEY_API, value.trim()).apply()
        _apiKey.value = value.trim()
    }

    fun setHotkeyMode(mode: HotkeyMode) {
        prefs.edit().putString(KEY_HOTKEY, mode.name).apply()
        _hotkeyMode.value = mode
    }

    fun setLanguage(value: String) {
        prefs.edit().putString(KEY_LANG, value).apply()
        _language.value = value
    }

    private fun readHotkeyMode(): HotkeyMode {
        // One-shot: move everyone onto Caps Lock after that option shipped.
        if (!prefs.getBoolean(KEY_CAPS_MIGRATED, false)) {
            prefs.edit()
                .putString(KEY_HOTKEY, HotkeyMode.CAPS_LOCK.name)
                .putBoolean(KEY_CAPS_MIGRATED, true)
                .apply()
            return HotkeyMode.CAPS_LOCK
        }
        val raw = prefs.getString(KEY_HOTKEY, HotkeyMode.CAPS_LOCK.name)
            ?: HotkeyMode.CAPS_LOCK.name
        return when (raw) {
            "CTRL_ALT", "CTRL_ALT_OR_FN" -> HotkeyMode.CTRL_ALT_SPACE
            "FN" -> HotkeyMode.FN_ALT
            else -> runCatching { HotkeyMode.valueOf(raw) }
                .getOrDefault(HotkeyMode.CAPS_LOCK)
        }
    }

    companion object {
        private const val KEY_API = "groq_api_key"
        private const val KEY_HOTKEY = "hotkey_mode"
        private const val KEY_LANG = "language"
        private const val KEY_CAPS_MIGRATED = "caps_lock_migrated_v1"
    }
}