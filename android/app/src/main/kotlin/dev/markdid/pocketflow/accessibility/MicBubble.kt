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
import dev.markdid.pocketflow.ui.DropletView
import kotlin.math.abs

/**
 * Floating dictation bubble drawn as an accessibility overlay (no "draw over other apps" permission needed). Tap to
 * start, tap again to finish; drag to move it along the screen edge.
 *
 * Drawn as a water droplet ([DropletView]): clear with a small mic at rest, filled blue with live level bars while
 * listening, and the resting drop with a spinning blue ring while writing. Light or dark rim, by default following the
 * system dark mode.
 */
class MicBubble(private val service: AccessibilityService, private val onTap: () -> Unit) {
    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val prefs = service.getSharedPreferences("pocketflow_bubble", Context.MODE_PRIVATE)
    private val size = dp(78)
    private var view: FrameLayout? = null
    private var droplet: DropletView? = null
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
        val drop = DropletView(service).apply { levelProvider = { DictationService.levelSource?.invoke() ?: 0f } }
        val container = FrameLayout(service).apply {
            contentDescription = "Dictate with PocketFlow"
            addView(drop, FrameLayout.LayoutParams(size, size))
            scaleX = 0.4f
            scaleY = 0.4f
            alpha = 0f
        }
        attachTouch(container)
        view = container
        droplet = drop
        render(state)
        runCatching { windowManager.addView(container, params) }.onFailure { view = null }
        container.animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(320)
            .setInterpolator(OvershootInterpolator(1.6f)).start()
    }

    fun hide() {
        val current = view ?: return
        view = null
        droplet = null
        current.animate().scaleX(0.4f).scaleY(0.4f).alpha(0f).setDuration(180).withEndAction {
            runCatching { windowManager.removeView(current) }
        }.start()
    }

    fun render(state: DictationState) {
        this.state = state
        val drop = droplet ?: return
        drop.dark = when (PocketFlowApp.instance.settings.bubbleStyle) {
            BubbleStyle.light -> false
            BubbleStyle.dark -> true
            BubbleStyle.auto -> (service.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        drop.mode = when (state) {
            DictationState.listening -> DropletView.Mode.LISTENING
            DictationState.transcribing -> DropletView.Mode.PROCESSING
            else -> DropletView.Mode.IDLE
        }
    }

    private fun squeeze(pressed: Boolean) {
        droplet?.squeezed = pressed
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
