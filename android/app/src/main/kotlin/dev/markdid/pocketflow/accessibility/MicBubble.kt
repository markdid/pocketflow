package dev.markdid.pocketflow.accessibility

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.ImageView
import dev.markdid.pocketflow.dictation.DictationState
import kotlin.math.abs

/**
 * Floating mic button drawn as an accessibility overlay (no "draw over other apps" permission needed). Tap to start,
 * tap again to finish; drag to move it up or down the screen edge.
 */
class MicBubble(private val service: AccessibilityService, private val onTap: () -> Unit) {
    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val prefs = service.getSharedPreferences("pocketflow_bubble", Context.MODE_PRIVATE)
    private val size = dp(52)
    private var view: ImageView? = null
    private val background = GradientDrawable().apply { shape = GradientDrawable.OVAL }

    private val params = WindowManager.LayoutParams(
        size,
        size,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.END or Gravity.TOP
        x = dp(8)
        y = prefs.getInt(KEY_Y, dp(320))
    }

    fun show() {
        if (view != null) return
        val bubble = ImageView(service).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            this.background = this@MicBubble.background
            elevation = dp(6).toFloat()
            alpha = 0.92f
            contentDescription = "Dictate with PocketFlow"
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        attachTouch(bubble)
        view = bubble
        render(DictationState.idle)
        runCatching { windowManager.addView(bubble, params) }.onFailure { view = null }
    }

    fun hide() {
        val current = view ?: return
        view = null
        runCatching { windowManager.removeView(current) }
    }

    fun render(state: DictationState) {
        background.setColor(
            when (state) {
                DictationState.listening -> 0xFFE53935.toInt()
                DictationState.transcribing -> 0xFF7986CB.toInt()
                else -> 0xFF3F51B5.toInt()
            },
        )
        view?.invalidate()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun attachTouch(bubble: ImageView) {
        var downY = 0f
        var startY = 0
        var dragging = false
        bubble.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downY = event.rawY
                    startY = params.y
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = event.rawY - downY
                    if (abs(dy) > dp(8)) dragging = true
                    if (dragging) {
                        params.y = (startY + dy).toInt().coerceAtLeast(0)
                        runCatching { windowManager.updateViewLayout(v, params) }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (dragging) prefs.edit().putInt(KEY_Y, params.y).apply() else onTap()
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
