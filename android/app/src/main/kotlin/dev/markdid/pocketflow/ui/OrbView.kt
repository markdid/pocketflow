package dev.markdid.pocketflow.ui

import android.content.Context
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.os.SystemClock
import android.view.View
import androidx.core.content.ContextCompat
import dev.markdid.pocketflow.R
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * The PocketFlow voice orb, drawn natively for the floating bubble and the keyboard. Mirrors the Flutter `VoiceOrb`:
 * a matte charcoal shape that ripples with the voice, with a rim that lights up in the signal color only while the
 * mic is live, and a thin white beam while writing.
 */
class OrbView(context: Context) : View(context) {
    enum class Mode { ASLEEP, IDLE, LISTENING, PROCESSING }

    var mode = Mode.IDLE
    var levelProvider: () -> Float = { 0f }

    /** Draw a small mic glyph at rest, so a bare orb still reads as "tap to talk". */
    var showMicWhenIdle = true
    var squeezed = false

    private val startedAt = SystemClock.uptimeMillis()
    private var lastFrame = 0f
    private var level = 0f
    private var energy = 0.18f
    private var spin = 0f
    private var processing = 0f
    private var asleep = 0f
    private var press = 0f

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val path = Path()
    private val matrix = Matrix()
    private val oval = RectF()
    private val mic = ContextCompat.getDrawable(context, R.drawable.ic_stat_mic)?.mutate()

    // Unit-radius gradients, positioned per frame with a local matrix instead of reallocating.
    private val body = RadialGradient(
        -0.45f, -0.55f, 1.25f,
        intArrayOf(0xFF4A4A50.toInt(), 0xFF1A1A1D.toInt(), 0xFF0C0C0E.toInt()),
        floatArrayOf(0f, 0.55f, 1f),
        Shader.TileMode.CLAMP,
    )
    private val glint = RadialGradient(0f, 0f, 1f, alpha(Color.WHITE, 0.10f), Color.TRANSPARENT, Shader.TileMode.CLAMP)
    private val glow = RadialGradient(
        0f, 0f, 1f,
        intArrayOf(alpha(SIGNAL, 0.14f), alpha(SIGNAL, 0.14f), Color.TRANSPARENT),
        floatArrayOf(0f, 0.7f, 1f),
        Shader.TileMode.CLAMP,
    )

    init {
        setLayerType(LAYER_TYPE_HARDWARE, null)
    }

    override fun onDraw(canvas: Canvas) {
        val now = (SystemClock.uptimeMillis() - startedAt) / 1000f
        val dt = (now - lastFrame).coerceIn(0f, 0.1f)
        lastFrame = now
        step(dt)

        val cx = width / 2f
        val cy = height / 2f
        val base = min(width, height) * 0.30f * (1 - press * 0.05f) * (1 + 0.015f * sin(now * 1.6f))
        val live = ((energy - 0.18f) / 0.82f).coerceIn(0f, 1f) * (1 - processing)
        val dim = 1 - asleep * 0.6f

        // Faint signal glow behind the orb while listening.
        if (live > 0.01f) {
            paint.alpha = (255 * live).toInt()
            fill(canvas, glow, cx, cy, base * (1.3f + level * 0.25f))
            paint.alpha = 255
        }

        val ripple = 0.018f + energy * 0.025f + level * 0.11f
        blob(cx, cy, base, now, ripple)

        // Matte charcoal body, lit from the top left.
        matrix.setScale(base, base)
        matrix.postTranslate(cx, cy)
        body.setLocalMatrix(matrix)
        paint.shader = body
        paint.alpha = (255 * (0.55f + 0.45f * dim)).toInt()
        canvas.drawPath(path, paint)
        paint.alpha = 255

        // Specular glint, clipped to the shape.
        val save = canvas.save()
        canvas.clipPath(path)
        paint.alpha = (255 * dim).toInt()
        matrix.setScale(base * 0.4f, base * 0.225f)
        matrix.postTranslate(cx - base * 0.4f, cy - base * 0.48f)
        glint.setLocalMatrix(matrix)
        paint.shader = glint
        oval.set(cx - base * 0.8f, cy - base * 0.705f, cx, cy - base * 0.255f)
        canvas.drawOval(oval, paint)
        paint.alpha = 255
        paint.shader = null
        canvas.restoreToCount(save)

        // Rim: a faint white edge at rest, the signal color while the mic is live.
        rimPaint.color = blend(alpha(Color.WHITE, 0.10f * dim), SIGNAL, live)
        rimPaint.strokeWidth = base * (0.035f + level * 0.025f)
        rimPaint.maskFilter = BLUR
        canvas.drawPath(path, rimPaint)

        if (showMicWhenIdle && mic != null && (mode == Mode.IDLE || mode == Mode.ASLEEP)) {
            val s = (base * 0.6f).toInt()
            mic.setBounds((cx - s / 2).toInt(), (cy - s / 2).toInt(), (cx + s / 2).toInt(), (cy + s / 2).toInt())
            mic.alpha = (255 * 0.7f * dim).toInt()
            mic.draw(canvas)
        }

        if (processing > 0.01f) {
            val r = base * 1.28f
            oval.set(cx - r, cy - r, cx + r, cy + r)
            val startDegrees = Math.toDegrees((spin * 1.6f).toDouble()).toFloat()
            val beam = SweepGradient(
                cx, cy,
                intArrayOf(Color.TRANSPARENT, alpha(Color.WHITE, 0.9f * processing), Color.TRANSPARENT),
                floatArrayOf(0f, 0.24f, 0.25f),
            )
            matrix.setRotate(startDegrees, cx, cy)
            beam.setLocalMatrix(matrix)
            paint.shader = beam
            paint.style = Paint.Style.STROKE
            paint.strokeCap = Paint.Cap.ROUND
            paint.strokeWidth = base * 0.022f
            canvas.drawArc(oval, startDegrees, 86f, false, paint)
            paint.style = Paint.Style.FILL
            paint.shader = null
        }

        if (isShown) postInvalidateOnAnimation()
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
            Mode.PROCESSING -> 0.55f
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

    private fun fill(canvas: Canvas, shader: Shader, x: Float, y: Float, radius: Float) {
        matrix.setScale(radius, radius)
        matrix.postTranslate(x, y)
        shader.setLocalMatrix(matrix)
        paint.shader = shader
        canvas.drawCircle(x, y, radius, paint)
        paint.shader = null
    }

    companion object {
        const val SIGNAL = 0xFFFF5A1F.toInt()
        private val BLUR = BlurMaskFilter(1.5f, BlurMaskFilter.Blur.NORMAL)

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
