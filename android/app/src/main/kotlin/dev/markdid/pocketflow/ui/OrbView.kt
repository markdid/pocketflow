package dev.markdid.pocketflow.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
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
 * drifting pools of aurora light inside a liquid shape that ripples with the voice, and a comet beam while writing.
 */
class OrbView(context: Context) : View(context) {
    enum class Mode { ASLEEP, IDLE, LISTENING, PROCESSING }

    var mode = Mode.IDLE
    var levelProvider: () -> Float = { 0f }

    /** Draw a small mic glyph when idle, so a bare orb still reads as "tap to talk". */
    var showMicWhenIdle = true

    private val startedAt = SystemClock.uptimeMillis()
    private var lastFrame = 0f
    private var level = 0f
    private var energy = 0.18f
    private var spin = 0f
    private var processing = 0f
    private var asleep = 0f
    private var press = 0f
    var squeezed = false

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val screen = PorterDuffXfermode(PorterDuff.Mode.SCREEN)
    private val path = Path()
    private val matrix = Matrix()
    private val oval = RectF()
    private val mic = ContextCompat.getDrawable(context, R.drawable.ic_stat_mic)?.mutate()

    // Unit-radius gradients, positioned per frame with a local matrix instead of reallocating.
    private val pools = listOf(
        Pool(MAGENTA, 0.55f, 0.62f, 0.78f, 0f),
        Pool(CYAN, -0.42f, 0.66f, 0.70f, 1.9f),
        Pool(AMBER, 0.33f, 0.58f, 0.55f, 3.6f),
        Pool(VIOLET, -0.25f, 0.35f, 0.95f, 5.0f),
    )
    private val white = radial(Color.WHITE)
    private val halo = RadialGradient(
        0f, 0f, 1f,
        intArrayOf(alpha(MAGENTA, 0.5f), alpha(VIOLET, 0.25f), alpha(VIOLET, 0f)),
        floatArrayOf(0.3f, 0.6f, 1f),
        Shader.TileMode.CLAMP,
    )
    private val body = RadialGradient(0.2f, 0.3f, 1.2f, 0xFF2B1870.toInt(), 0xFF0D0820.toInt(), Shader.TileMode.CLAMP)
    private val falloff = RadialGradient(
        0f, 0f, 1.15f,
        intArrayOf(Color.TRANSPARENT, Color.TRANSPARENT, alpha(Color.BLACK, 0.45f)),
        floatArrayOf(0f, 0.55f, 0.85f),
        Shader.TileMode.CLAMP,
    )
    private val rim = SweepGradient(0f, 0f, intArrayOf(VIOLET, MAGENTA, AMBER, CYAN, VIOLET), null)

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
        val base = min(width, height) * 0.30f * (1 - press * 0.06f) * (1 + 0.02f * sin(now * 1.6f))
        val wake = 1 - asleep * 0.7f

        // Halo.
        val haloRadius = base * (1.6f + energy * 0.45f + level * 0.3f)
        paint.alpha = (255 * wake * (0.45f + energy * 0.55f)).toInt().coerceIn(0, 255)
        draw(canvas, halo, cx, cy, haloRadius)
        paint.alpha = 255

        val ripple = 0.025f + energy * 0.035f + level * 0.13f
        blob(cx, cy, base, now, ripple)

        val save = canvas.saveLayer(cx - base * 1.3f, cy - base * 1.3f, cx + base * 1.3f, cy + base * 1.3f, null)
        canvas.clipPath(path)
        draw(canvas, body, cx, cy, base)

        paint.xfermode = screen
        val drift = 0.75f + energy * 0.5f
        for (pool in pools) {
            val a = now * pool.speed * drift + pool.phase + spin * 0.5f
            val x = cx + cos(a) * base * pool.orbit * (0.8f + level * 0.5f)
            val y = cy + sin(a * 1.3f) * base * pool.orbit * (0.8f + level * 0.5f)
            paint.alpha = (255 * 0.85f * wake).toInt()
            draw(canvas, pool.shader, x, y, base * pool.size * (0.9f + level * 0.35f))
        }
        paint.alpha = (255 * wake * (0.04f + level * 0.3f)).toInt().coerceIn(0, 255)
        draw(canvas, white, cx, cy, base * (0.35f + level * 0.45f))
        paint.alpha = 255
        paint.xfermode = null

        draw(canvas, falloff, cx, cy, base)

        // Inner rim of aurora light.
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = base * 0.07f
        paint.xfermode = screen
        paint.alpha = (255 * 0.7f * wake).toInt()
        matrix.setRotate(Math.toDegrees((spin + now * 0.2f).toDouble()).toFloat())
        matrix.postTranslate(cx, cy)
        rim.setLocalMatrix(matrix)
        paint.shader = rim
        canvas.drawPath(path, paint)
        paint.style = Paint.Style.FILL
        paint.xfermode = null
        paint.alpha = 255

        // Specular glint.
        paint.alpha = (255 * 0.42f * wake).toInt()
        matrix.setScale(base * 0.35f, base * 0.21f)
        matrix.postTranslate(cx - base * 0.38f, cy - base * 0.45f)
        white.setLocalMatrix(matrix)
        paint.shader = white
        oval.set(cx - base * 0.73f, cy - base * 0.66f, cx - base * 0.03f, cy - base * 0.24f)
        canvas.drawOval(oval, paint)
        paint.alpha = 255

        if (asleep > 0.01f) {
            paint.shader = null
            paint.color = alpha(INK, 0.5f * asleep)
            canvas.drawCircle(cx, cy, base * 1.3f, paint)
        }
        canvas.restoreToCount(save)
        paint.shader = null

        if (showMicWhenIdle && mic != null && (mode == Mode.IDLE || mode == Mode.ASLEEP)) {
            val s = (base * 0.62f).toInt()
            mic.setBounds((cx - s / 2).toInt(), (cy - s / 2).toInt(), (cx + s / 2).toInt(), (cy + s / 2).toInt())
            mic.alpha = (255 * 0.85f).toInt()
            mic.draw(canvas)
        }

        if (processing > 0.01f) {
            val r = base * 1.3f
            oval.set(cx - r, cy - r, cx + r, cy + r)
            val start = spin * 1.6f
            val comet = SweepGradient(
                cx, cy,
                intArrayOf(alpha(CYAN, 0f), alpha(CYAN, 0.85f * processing), alpha(Color.WHITE, processing), Color.TRANSPARENT),
                floatArrayOf(0f, 0.22f, 0.25f, 0.26f),
            )
            matrix.setRotate(Math.toDegrees(start.toDouble()).toFloat(), cx, cy)
            comet.setLocalMatrix(matrix)
            paint.shader = comet
            paint.style = Paint.Style.STROKE
            paint.strokeCap = Paint.Cap.ROUND
            paint.strokeWidth = base * 0.04f
            canvas.drawArc(oval, Math.toDegrees(start.toDouble()).toFloat(), 86f, false, paint)
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

    private fun draw(canvas: Canvas, shader: Shader, x: Float, y: Float, radius: Float) {
        matrix.setScale(radius, radius)
        matrix.postTranslate(x, y)
        shader.setLocalMatrix(matrix)
        paint.shader = shader
        canvas.drawCircle(x, y, radius * 1.3f, paint)
        paint.shader = null
    }

    private class Pool(color: Int, val speed: Float, val orbit: Float, val size: Float, val phase: Float) {
        val shader = radial(color)
    }

    companion object {
        const val INK = 0xFF06060A.toInt()
        const val VIOLET = 0xFF7B61FF.toInt()
        const val MAGENTA = 0xFFFF4FD8.toInt()
        const val AMBER = 0xFFFFB347.toInt()
        const val CYAN = 0xFF35E0FF.toInt()

        fun alpha(color: Int, a: Float) = Color.argb((a.coerceIn(0f, 1f) * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

        private fun radial(color: Int) =
            RadialGradient(0f, 0f, 1f, color, alpha(color, 0f), Shader.TileMode.CLAMP)
    }
}
