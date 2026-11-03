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
import kotlin.math.min
import kotlin.math.sin

/**
 * The floating bubble's listening look: a blue disc, lit like the pearl, with live white level bars, which reads at a glance over
 * any app. (At rest and while writing the bubble shows the pearl [OrbView].)
 */
class BubbleView(context: Context) : View(context) {
    var levelProvider: () -> Float = { 0f }
    var dark = false
    var squeezed = false

    /** Stop animating while faded out (the bubble shows only one of its two looks at a time). */
    var paused = false
        set(value) {
            field = value
            if (!value) postInvalidateOnAnimation()
        }

    private val startedAt = SystemClock.uptimeMillis()
    private var lastFrame = 0f
    private var press = 0f
    private val bars = FloatArray(5)

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val oval = RectF()

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

        // Shadow: a soft gradient ellipse, so it shows over any background without blur support.
        val shadowRadius = r * 1.35f
        fill.shader = RadialGradient(
            cx, cy + r * 0.18f, shadowRadius,
            intArrayOf(if (dark) 0x99000000.toInt() else 0x330F1115, Color.TRANSPARENT),
            floatArrayOf(0.62f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy + r * 0.18f, shadowRadius, fill)
        fill.shader = null

        // Blue disc lit like the pearl: broad light from above, a glow low inside, a soft darker rim. This view has no
        // other look: it stays blue while it fades out.
        fill.shader = RadialGradient(
            cx - r * 0.15f, cy - r * 0.6f, r * 1.5f,
            intArrayOf(0xFF3F8DEB.toInt(), ACCENT, 0xFF0758B6.toInt()),
            floatArrayOf(0f, 0.5f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, r, fill)
        fill.shader = RadialGradient(
            cx + r * 0.1f, cy + r * 0.62f, r * 0.7f,
            0x8082BEFF.toInt(), Color.TRANSPARENT,
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, r, fill)
        fill.shader = RadialGradient(
            cx, cy, r * 1.03f,
            intArrayOf(Color.TRANSPARENT, 0x47001946), floatArrayOf(0.76f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, r, fill)
        fill.shader = null
        stroke.strokeWidth = r * 0.05f
        stroke.color = 0x1FFFFFFF
        canvas.drawCircle(cx, cy, r - stroke.strokeWidth / 2, stroke)
        drawBars(canvas, cx, cy, r, dt, now)

        if (isShown && !paused) postInvalidateOnAnimation()
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
    }
}
