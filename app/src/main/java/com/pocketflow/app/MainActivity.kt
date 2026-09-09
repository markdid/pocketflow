package com.pocketflow.app

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.pocketflow.app.data.HotkeyMode
import com.pocketflow.app.databinding.ActivityMainBinding
import com.pocketflow.app.dictation.DictationBus
import com.pocketflow.app.dictation.DictationService
import com.pocketflow.app.dictation.DictationState
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { refreshChecks() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        val settings = PocketFlowApp.instance.settings
        binding.apiKeyInput.setText(settings.apiKey.value)
        when (settings.hotkeyMode.value) {
            HotkeyMode.CAPS_LOCK -> binding.hotkeyCaps.isChecked = true
            HotkeyMode.CTRL_SHIFT_SPACE -> binding.hotkeyCtrlShift.isChecked = true
            HotkeyMode.ALL -> binding.hotkeyAll.isChecked = true
            HotkeyMode.CTRL_ALT_SPACE -> binding.hotkeyCtrlAlt.isChecked = true
            HotkeyMode.ALT_SPACE -> binding.hotkeyAltSpace.isChecked = true
            HotkeyMode.FN_ALT -> binding.hotkeyFnAlt.isChecked = true
        }

        binding.btnPermissions.setOnClickListener { requestNeededPermissions() }
        binding.btnAccessibility.setOnClickListener {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
        binding.btnImeSettings.setOnClickListener {
            startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
        }
        binding.btnImePicker.setOnClickListener {
            getSystemService(InputMethodManager::class.java).showInputMethodPicker()
        }
        binding.btnSaveKey.setOnClickListener {
            settings.setApiKey(binding.apiKeyInput.text?.toString().orEmpty())
            refreshChecks()
        }
        binding.hotkeyGroup.setOnCheckedChangeListener { _, checkedId ->
            val mode = when (checkedId) {
                R.id.hotkeyCtrlShift -> HotkeyMode.CTRL_SHIFT_SPACE
                R.id.hotkeyAll -> HotkeyMode.ALL
                R.id.hotkeyCtrlAlt -> HotkeyMode.CTRL_ALT_SPACE
                R.id.hotkeyAltSpace -> HotkeyMode.ALT_SPACE
                R.id.hotkeyFnAlt -> HotkeyMode.FN_ALT
                else -> HotkeyMode.CAPS_LOCK
            }
            settings.setHotkeyMode(mode)
        }
        binding.btnArm.setOnClickListener {
            if (DictationBus.armed.value) DictationService.disarm(this)
            else DictationService.arm(this)
        }
        binding.btnTest.setOnClickListener { DictationService.toggle(this) }

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                launch {
                    DictationBus.status.collect { status ->
                        binding.statusTitle.text = when (status.state) {
                            DictationState.LISTENING -> "Listening"
                            DictationState.TRANSCRIBING -> "Transcribing"
                            DictationState.ERROR -> "Error"
                            DictationState.IDLE -> "PocketFlow"
                        }
                        binding.statusMessage.text = status.message.ifBlank { defaultMessage() }
                        val pulse = binding.statusPulse.background as? GradientDrawable
                            ?: GradientDrawable().also {
                                it.shape = GradientDrawable.OVAL
                                binding.statusPulse.background = it
                            }
                        pulse.setColor(
                            when (status.state) {
                                DictationState.LISTENING -> 0xFFEF4444.toInt()
                                DictationState.TRANSCRIBING -> 0xFFF59E0B.toInt()
                                DictationState.ERROR -> 0xFFEF4444.toInt()
                                DictationState.IDLE -> if (DictationBus.armed.value) {
                                    0xFF22C55E.toInt()
                                } else {
                                    0xFF0EA5E9.toInt()
                                }
                            },
                        )
                        if (status.lastTranscript.isNotBlank()) {
                            binding.lastTranscript.visibility = android.view.View.VISIBLE
                            binding.lastTranscript.text = "“${status.lastTranscript}”"
                        }
                    }
                }
                launch {
                    DictationBus.armed.collect {
                        binding.btnArm.text = if (it) "Disarm" else "Arm PocketFlow"
                        refreshChecks()
                    }
                }
                launch {
                    DictationBus.accessibilityConnected.collect { refreshChecks() }
                }
                launch {
                    settings.apiKey.collect { refreshChecks() }
                }
                launch {
                    DictationBus.transcriptHistory.collect { history ->
                        renderTranscriptHistory(history)
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Settings toggles / desktop-mode rebinds can leave the in-memory flag stale.
        if (com.pocketflow.app.hotkey.DictationAccessibilityService.isEnabled()) {
            DictationBus.setAccessibilityConnected(true)
        }
        refreshChecks()
    }

    private fun renderTranscriptHistory(history: List<String>) {
        val container = binding.transcriptHistory
        container.removeAllViews()
        binding.transcriptHistoryEmpty.visibility =
            if (history.isEmpty()) android.view.View.VISIBLE else android.view.View.GONE

        val density = resources.displayMetrics.density
        history.forEach { text ->
            val row = TextView(this).apply {
                this.text = text
                setTextColor(0xFF0B1220.toInt())
                textSize = 15f
                setPadding(
                    (12 * density).toInt(),
                    (12 * density).toInt(),
                    (12 * density).toInt(),
                    (12 * density).toInt(),
                )
                setBackgroundColor(0xFFF8FAFC.toInt())
                isClickable = true
                isFocusable = true
                setOnClickListener { copyTranscript(text) }
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = (8 * density).toInt()
            }
            container.addView(row, lp)
        }
    }

    private fun copyTranscript(text: String) {
        val clipboard = getSystemService(ClipboardManager::class.java)
        clipboard.setPrimaryClip(ClipData.newPlainText("PocketFlow", text))
        Toast.makeText(this, "Copied", Toast.LENGTH_SHORT).show()
    }

    private fun defaultMessage(): String {
        val settings = PocketFlowApp.instance.settings
        return when {
            !micGranted() -> "Microphone permission needed"
            settings.apiKey.value.isBlank() -> "Add your Groq API key"
            !DictationBus.accessibilityConnected.value -> "Enable Accessibility for hotkeys"
            !DictationBus.armed.value -> "Arm the service, then dictate from any app"
            else -> "Ready — hold Caps Lock"
        }
    }

    private fun refreshChecks() {
        binding.checkMic.text = checkLabel("Microphone", micGranted())
        binding.checkNotif.text = checkLabel("Notifications", notifGranted())
        binding.checkApi.text = checkLabel(
            "Groq API key",
            PocketFlowApp.instance.settings.apiKey.value.isNotBlank(),
        )
        binding.checkA11y.text = checkLabel(
            "Accessibility (hotkeys)",
            DictationBus.accessibilityConnected.value,
        )
        binding.checkArmed.text = checkLabel("Service armed", DictationBus.armed.value)
        if (binding.statusMessage.text.isNullOrBlank() ||
            DictationBus.status.value.state == DictationState.IDLE
        ) {
            binding.statusMessage.text = defaultMessage()
        }
    }

    private fun checkLabel(label: String, ok: Boolean): String =
        (if (ok) "✓ " else "○ ") + label

    private fun micGranted(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun notifGranted(): Boolean =
        if (Build.VERSION.SDK_INT >= 33) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

    private fun requestNeededPermissions() {
        val needed = buildList {
            if (!micGranted()) add(Manifest.permission.RECORD_AUDIO)
            if (Build.VERSION.SDK_INT >= 33 && !notifGranted()) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (needed.isNotEmpty()) permissionLauncher.launch(needed.toTypedArray())
        else {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
        }
    }
}
