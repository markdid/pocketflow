package dev.markdid.pocketflow.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.view.View
import androidx.core.content.ContextCompat
import dev.markdid.pocketflow.R
import kotlin.math.min
import kotlin.math.sin

/**
 * The floating dictation button. Unlike the in-app orb it has to read at a glance over any app, light or dark, so
 * every state keeps strong contrast: a solid disc with a mic at rest, solid blue with live level bars while
 * listening, and a spinning ring while writing.
 */
class BubbleView(context: Context) : View(context) {
    enum class Mode { IDLE, LISTENING, PROCESSING }

    var mode = Mode.IDLE
    var levelProvider: () -> Float = { 0f }
    var dark = false
    var squeezed = false

    private val startedAt = SystemClock.uptimeMillis()
    private var lastFrame = 0f
    private var press = 0f
    private val bars = FloatArray(5)

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val oval = RectF()
    private val mic = ContextCompat.getDrawable(context, R.drawable.ic_stat_mic)?.mutate()

    init {
        setLayerType(LAYER_TYPE_HARDWARE, null)
    }

    override fun onDraw(canvas: Canvas) {
        val now = (SystemClock.uptimeMillis() - startedAt) / 1000f
        val dt = (now - lastFrame).coerceIn(0f, 0.1f)
        lastFrame = now
        press += ((if (squeezed) 1f else 0f) - press) * min(1f, dt * 14f)

        val cx = width / 2f
        val cy = height / 2f
        val r = min(width, height) * 0.31f * (1 - press * 0.06f)
        val listening = mode == Mode.LISTENING

        // Shadow: a soft gradient ellipse, so it shows over any background without blur support.
        val shadowRadius = r * 1.35f
        fill.shader = RadialGradient(
            cx, cy + r * 0.18f, shadowRadius,
            intArrayOf(if (dark) 0x99000000.toInt() else 0x4D0F1115, Color.TRANSPARENT),
            floatArrayOf(0.62f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy + r * 0.18f, shadowRadius, fill)
        fill.shader = null

        // Disc.
        fill.color = when {
            listening -> ACCENT
            dark -> 0xFF22252F.toInt()
            else -> Color.WHITE
        }
        canvas.drawCircle(cx, cy, r, fill)
        stroke.strokeWidth = r * 0.05f
        stroke.color = when {
            listening -> 0x33FFFFFF
            dark -> 0x2EFFFFFF
            else -> 0x2E0F1115
        }
        canvas.drawCircle(cx, cy, r - stroke.strokeWidth / 2, stroke)

        if (listening) {
            drawBars(canvas, cx, cy, r, dt, now)
        } else {
            val s = (r * 1.0f).toInt()
            mic?.setBounds((cx - s / 2).toInt(), (cy - s / 2).toInt(), (cx + s / 2).toInt(), (cy + s / 2).toInt())
            mic?.setTint(if (dark) Color.WHITE else INK)
            mic?.draw(canvas)
        }

        if (mode == Mode.PROCESSING) {
            val ringR = r * 1.18f
            oval.set(cx - ringR, cy - ringR, cx + ringR, cy + ringR)
            stroke.color = if (dark) ACCENT_ON_DARK else ACCENT
            stroke.strokeWidth = r * 0.13f
            stroke.strokeCap = Paint.Cap.ROUND
            canvas.drawArc(oval, (now * 360f) % 360f, 100f, false, stroke)
        }

        if (isShown) postInvalidateOnAnimation()
    }

    /** Five white bars that follow the voice, centred in the blue disc. */
    private fun drawBars(canvas: Canvas, cx: Float, cy: Float, r: Float, dt: Float, now: Float) {
        val level = levelProvider().coerceIn(0f, 1f)
        val barWidth = r * 0.16f
        val gap = r * 0.12f
        val maxHeight = r * 1.05f
        val left = cx - (bars.size * barWidth + (bars.size - 1) * gap) / 2
        fill.color = Color.WHITE
        for (i in bars.indices) {
            // Each bar gets its own wobble so the group moves like a voice, not a single meter.
            val shape = 0.55f + 0.45f * sin(now * 9f + i * 1.3f)
            val target = (0.18f + level * shape).coerceIn(0.18f, 1f)
            bars[i] += (target - bars[i]) * min(1f, dt * if (target > bars[i]) 20f else 6f)
            val h = maxHeight * bars[i]
            val x = left + i * (barWidth + gap)
            oval.set(x, cy - h / 2, x + barWidth, cy + h / 2)
            canvas.drawRoundRect(oval, barWidth / 2, barWidth / 2, fill)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        postInvalidateOnAnimation()
    }

    private companion object {
        const val ACCENT = 0xFF0A6CDB.toInt()
        const val ACCENT_ON_DARK = 0xFF5AA2FF.toInt()
        const val INK = 0xFF0F1115.toInt()
    }
}
