package dev.markdid.pocketflow.accessibility

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.content.res.Configuration
import dev.markdid.pocketflow.BubbleStyle
import dev.markdid.pocketflow.PocketFlowApp
import dev.markdid.pocketflow.dictation.DictationService
import dev.markdid.pocketflow.dictation.DictationState
import dev.markdid.pocketflow.ui.BubbleView
import dev.markdid.pocketflow.ui.OrbView
import kotlin.math.abs

/**
 * Floating dictation bubble drawn as an accessibility overlay (no "draw over other apps" permission needed). Tap to
 * start, tap again to finish; drag to move it along the screen edge.
 *
 * At rest it's the subtle pearl orb with a small mic, a little translucent. While busy it cross-fades to a solid
 * button that reads on any screen: blue with live level bars while listening, a spinning ring while writing. Pearl or
 * graphite, by default following the system dark mode.
 */
class MicBubble(private val service: AccessibilityService, private val onTap: () -> Unit) {
    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val prefs = service.getSharedPreferences("pocketflow_bubble", Context.MODE_PRIVATE)
    private val size = dp(78)
    private var view: FrameLayout? = null
    private var orb: OrbView? = null
    private var button: BubbleView? = null
    private var state = DictationState.idle

    private val params = WindowManager.LayoutParams(
        size,
        size,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.END or Gravity.TOP
        x = 0
        y = prefs.getInt(KEY_Y, dp(320))
    }

    fun show() {
        if (view != null) return
        val level = { DictationService.levelSource?.invoke() ?: 0f }
        val restingOrb = OrbView(service).apply { levelProvider = level }
        val busyButton = BubbleView(service).apply {
            levelProvider = level
            alpha = 0f
        }
        val container = FrameLayout(service).apply {
            contentDescription = "Dictate with PocketFlow"
            addView(restingOrb, FrameLayout.LayoutParams(size, size))
            addView(busyButton, FrameLayout.LayoutParams(size, size))
            scaleX = 0.4f
            scaleY = 0.4f
            alpha = 0f
        }
        attachTouch(container)
        view = container
        orb = restingOrb
        button = busyButton
        render(state)
        runCatching { windowManager.addView(container, params) }.onFailure { view = null }
        container.animate().scaleX(1f).scaleY(1f).alpha(restingAlpha()).setDuration(320)
            .setInterpolator(OvershootInterpolator(1.6f)).start()
    }

    fun hide() {
        val current = view ?: return
        view = null
        orb = null
        button = null
        current.animate().scaleX(0.4f).scaleY(0.4f).alpha(0f).setDuration(180).withEndAction {
            runCatching { windowManager.removeView(current) }
        }.start()
    }

    fun render(state: DictationState) {
        this.state = state
        val container = view ?: return
        val dark = when (PocketFlowApp.instance.settings.bubbleStyle) {
            BubbleStyle.light -> false
            BubbleStyle.dark -> true
            BubbleStyle.auto -> (service.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        val busy = state == DictationState.listening || state == DictationState.transcribing
        orb?.apply {
            this.dark = dark
            mode = OrbView.Mode.IDLE
            paused = busy
            animate().alpha(if (busy) 0f else 1f).setDuration(180).start()
        }
        button?.apply {
            this.dark = dark
            mode = when (state) {
                DictationState.listening -> BubbleView.Mode.LISTENING
                DictationState.transcribing -> BubbleView.Mode.PROCESSING
                else -> BubbleView.Mode.IDLE
            }
            paused = !busy
            animate().alpha(if (busy) 1f else 0f).setDuration(180).start()
        }
        container.animate().alpha(restingAlpha()).setDuration(200).start()
    }

    /** Slightly see-through at rest so it doesn't cover what's beneath; fully solid while it's working. */
    private fun restingAlpha() = if (state == DictationState.listening || state == DictationState.transcribing) 1f else 0.9f

    private fun squeeze(pressed: Boolean) {
        orb?.squeezed = pressed
        button?.squeezed = pressed
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun attachTouch(container: FrameLayout) {
        var downY = 0f
        var startY = 0
        var dragging = false
        container.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downY = event.rawY
                    startY = params.y
                    dragging = false
                    squeeze(true)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = event.rawY - downY
                    if (abs(dy) > dp(8)) {
                        dragging = true
                        squeeze(false)
                    }
                    if (dragging) {
                        params.y = (startY + dy).toInt().coerceAtLeast(0)
                        runCatching { windowManager.updateViewLayout(v, params) }
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    squeeze(false)
                    if (dragging) {
                        prefs.edit().putInt(KEY_Y, params.y).apply()
                    } else if (event.action == MotionEvent.ACTION_UP) {
                        v.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
                        onTap()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun dp(value: Int) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), service.resources.displayMetrics).toInt()

    private companion object {
        const val KEY_Y = "y"
    }
}
