package dev.markdid.pocketflow.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.view.View
import androidx.core.content.ContextCompat
import dev.markdid.pocketflow.R
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * The PocketFlow voice orb, drawn natively for the floating bubble and the keyboard. Mirrors the Flutter `VoiceOrb`:
 * a pearl that ripples with the voice and gains a soft blue halo while listening, with a thin blue beam while
 * writing. [dark] switches to a graphite version for dark screens.
 */
class OrbView(context: Context) : View(context) {
    enum class Mode { ASLEEP, IDLE, LISTENING, PROCESSING }

    var mode = Mode.IDLE
    var levelProvider: () -> Float = { 0f }

    /** Draw the mic glyph (and the listening bars), so a bare orb still reads as "tap to talk". */
    var showMicWhenIdle = true
    var squeezed = false

    /** Stop animating while faded out (the bubble shows only one of its two looks at a time). */
    var paused = false
        set(value) {
            field = value
            if (!value) postInvalidateOnAnimation()
        }

    var dark = false
        set(value) {
            field = value
            palette = if (value) GRAPHITE else PEARL
        }
    private var palette = PEARL

    private val startedAt = SystemClock.uptimeMillis()
    private var lastFrame = 0f
    private var level = 0f
    private var energy = 0.18f
    private var spin = 0f
    private var processing = 0f
    private var asleep = 0f
    private var press = 0f

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val path = Path()
    private val matrix = Matrix()
    private val oval = RectF()
    private val mic = ContextCompat.getDrawable(context, R.drawable.ic_stat_mic)?.mutate()
    private val bars = FloatArray(5)

    init {
        setLayerType(LAYER_TYPE_HARDWARE, null)
    }

    override fun onDraw(canvas: Canvas) {
        val now = (SystemClock.uptimeMillis() - startedAt) / 1000f
        val dt = (now - lastFrame).coerceIn(0f, 0.1f)
        lastFrame = now
        step(dt)

        val p = palette
        val cx = width / 2f
        val cy = height / 2f
        val base = min(width, height) * 0.30f * (1 - press * 0.05f) * (1 + 0.015f * sin(now * 1.6f))
        val live = ((energy - 0.18f) / 0.82f).coerceIn(0f, 1f) * (1 - processing)

        // Soft halo rings while listening.
        if (live > 0.01f) {
            paint.shader = null
            paint.color = alpha(p.accent, p.haloOuter * live)
            canvas.drawCircle(cx, cy, base * (1.36f + level * 0.16f), paint)
            paint.color = alpha(p.accent, p.haloInner * live)
            canvas.drawCircle(cx, cy, base * (1.17f + level * 0.1f), paint)
        }

        val ripple = 0.016f + energy * 0.02f + level * 0.09f
        blob(cx, cy, base, now, ripple)

        // Drop shadow: a soft ellipse below the orb (a gradient, so it works without blur support).
        val shadowColor = blend(p.shadow, alpha(p.accent, 0.35f), live)
        p.shadowShader(shadowColor).let { shader ->
            matrix.setScale(base * 1.05f, base * 0.7f)
            matrix.postTranslate(cx, cy + base * 0.55f)
            shader.setLocalMatrix(matrix)
            paint.shader = shader
            oval.set(cx - base * 1.05f, cy - base * 0.15f, cx + base * 1.05f, cy + base * 1.25f)
            canvas.drawOval(oval, paint)
        }

        // Body, lit broadly from above.
        matrix.setScale(base, base)
        matrix.postTranslate(cx, cy)
        p.body.setLocalMatrix(matrix)
        paint.shader = p.body
        canvas.drawPath(path, paint)

        // Light scattered through the pearl, gathering low on the side away from the light; tinted with the accent
        // while listening.
        val save = canvas.save()
        canvas.clipPath(path)
        val gx = cx + base * 0.1f
        val gy = cy + base * 0.62f
        paint.shader = RadialGradient(
            gx, gy, base * 0.7f,
            blend(p.glow, alpha(p.accent, 0.28f), live), Color.TRANSPARENT,
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(gx, gy, base * 0.7f, paint)
        // A soft darker rim instead of a hard outline, so it holds its shape on screens of its own color.
        paint.shader = RadialGradient(
            cx, cy, base * 1.03f,
            intArrayOf(Color.TRANSPARENT, p.rim), floatArrayOf(0.76f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, base * 1.03f, paint)
        paint.shader = null
        if (asleep > 0.01f) {
            paint.color = alpha(p.background, 0.45f * asleep)
            canvas.drawCircle(cx, cy, base * 1.3f, paint)
        }
        canvas.restoreToCount(save)

        // Faint hairline edge.
        strokePaint.shader = null
        strokePaint.color = p.edge
        strokePaint.strokeWidth = base * 0.035f
        canvas.drawPath(path, strokePaint)

        // Centre mark: the mic at rest and while writing, live bars in the accent while listening. The orb itself is
        // subtle, so this is what keeps it readable against a screen of the same color.
        if (showMicWhenIdle && mode == Mode.LISTENING) {
            drawBars(canvas, cx, cy, base, dt, now, p.accent)
        } else if (showMicWhenIdle && mic != null) {
            val s = (base * 0.6f).toInt()
            mic.setBounds((cx - s / 2).toInt(), (cy - s / 2).toInt(), (cx + s / 2).toInt(), (cy + s / 2).toInt())
            mic.setTint(p.glyph)
            mic.draw(canvas)
        }

        if (processing > 0.01f) {
            // Writing: a solid accent arc spinning around the resting orb.
            val r = base * 1.2f
            oval.set(cx - r, cy - r, cx + r, cy + r)
            strokePaint.shader = null
            strokePaint.color = alpha(p.accent, processing)
            strokePaint.strokeCap = Paint.Cap.ROUND
            strokePaint.strokeWidth = base * 0.12f
            canvas.drawArc(oval, (spin * 140f) % 360f, 100f, false, strokePaint)
            strokePaint.shader = null
        }

        if (isShown && !paused) postInvalidateOnAnimation()
    }

    private fun drawBars(canvas: Canvas, cx: Float, cy: Float, base: Float, dt: Float, now: Float, color: Int) {
        val barWidth = base * 0.11f
        val gap = base * 0.09f
        val maxHeight = base * 0.8f
        val left = cx - (bars.size * barWidth + (bars.size - 1) * gap) / 2
        paint.shader = null
        paint.color = color
        for (i in bars.indices) {
            // Each bar wobbles on its own so the group moves like a voice, not a single meter.
            val shape = 0.55f + 0.45f * sin(now * 9f + i * 1.3f)
            val target = (0.2f + level * 1.2f * shape).coerceIn(0.2f, 1f)
            bars[i] += (target - bars[i]) * min(1f, dt * if (target > bars[i]) 20f else 6f)
            val h = maxHeight * bars[i]
            val x = left + i * (barWidth + gap)
            oval.set(x, cy - h / 2, x + barWidth, cy + h / 2)
            canvas.drawRoundRect(oval, barWidth / 2, barWidth / 2, paint)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        postInvalidateOnAnimation()
    }

    private fun step(dt: Float) {
        val target = if (mode == Mode.LISTENING) levelProvider().coerceIn(0f, 1f) else 0f
        val targetEnergy = when (mode) {
            Mode.ASLEEP -> 0f
            Mode.IDLE -> 0.18f
            Mode.LISTENING -> 0.45f + target * 0.55f
            Mode.PROCESSING -> 0.18f // looks exactly like rest; only the ring is added
        }
        level += (target - level) * min(1f, dt * if (target > level) 18f else 4f)
        energy += (targetEnergy - energy) * min(1f, dt * 3f)
        spin += dt * if (mode == Mode.PROCESSING) 2.4f else 0.35f
        processing += ((if (mode == Mode.PROCESSING) 1f else 0f) - processing) * min(1f, dt * 4f)
        asleep += ((if (mode == Mode.ASLEEP) 1f else 0f) - asleep) * min(1f, dt * 3f)
        press += ((if (squeezed) 1f else 0f) - press) * min(1f, dt * 14f)
    }

    private fun blob(cx: Float, cy: Float, radius: Float, t: Float, ripple: Float) {
        path.reset()
        val points = 96
        for (i in 0..points) {
            val a = i / points.toFloat() * 2 * Math.PI.toFloat()
            val wobble = sin(3 * a + t * 1.7f) + 0.6f * sin(5 * a - t * 2.3f + 1.1f) + 0.35f * sin(8 * a + t * 3.4f - 0.7f)
            val r = radius * (1 + ripple * wobble / 1.95f)
            val x = cx + cos(a) * r
            val y = cy + sin(a) * r
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
    }

    private class Palette(
        val body: RadialGradient,
        val accent: Int,
        val shadow: Int,
        val glow: Int,
        val rim: Int,
        val glyph: Int,
        val edge: Int,
        val background: Int,
        val haloInner: Float,
        val haloOuter: Float,
    ) {
        fun shadowShader(color: Int) = RadialGradient(0f, 0f, 1f, color, Color.TRANSPARENT, Shader.TileMode.CLAMP)
    }

    companion object {
        private val PEARL = Palette(
            body = RadialGradient(
                -0.15f, -0.6f, 1.5f,
                intArrayOf(0xFFFFFFFF.toInt(), 0xFFF4F6F9.toInt(), 0xFFE2E7EE.toInt(), 0xFFD5DBE4.toInt()),
                floatArrayOf(0f, 0.4f, 0.78f, 1f),
                Shader.TileMode.CLAMP,
            ),
            accent = 0xFF0A6CDB.toInt(),
            shadow = 0x571E283C,
            glow = 0xE6FFFFFF.toInt(),
            rim = 0x2928344B,
            glyph = 0x8C0F1115.toInt(),
            edge = 0x120F1115,
            background = 0xFFF5F6F8.toInt(),
            haloInner = 0.10f,
            haloOuter = 0.05f,
        )
        private val GRAPHITE = Palette(
            body = RadialGradient(
                -0.15f, -0.6f, 1.5f,
                intArrayOf(0xFF525A6E.toInt(), 0xFF363C4D.toInt(), 0xFF22262F.toInt()),
                floatArrayOf(0f, 0.5f, 1f),
                Shader.TileMode.CLAMP,
            ),
            accent = 0xFF5AA2FF.toInt(),
            shadow = 0x80000000.toInt(),
            glow = 0x4D96AAD2,
            rim = 0x59000000,
            glyph = 0xB3FFFFFF.toInt(),
            edge = 0x0FFFFFFF,
            background = 0xFF14161C.toInt(),
            haloInner = 0.18f,
            haloOuter = 0.09f,
        )

        fun alpha(color: Int, a: Float) =
            Color.argb((a.coerceIn(0f, 1f) * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

        private fun blend(from: Int, to: Int, t: Float): Int {
            val u = t.coerceIn(0f, 1f)
            fun ch(a: Int, b: Int) = (a + (b - a) * u).toInt()
            return Color.argb(
                ch(Color.alpha(from), Color.alpha(to)),
                ch(Color.red(from), Color.red(to)),
                ch(Color.green(from), Color.green(to)),
                ch(Color.blue(from), Color.blue(to)),
            )
        }
    }
}
