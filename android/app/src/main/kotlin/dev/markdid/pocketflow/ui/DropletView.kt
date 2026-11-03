package dev.markdid.pocketflow.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
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
import androidx.core.graphics.ColorUtils
import dev.markdid.pocketflow.R
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * The floating bubble, drawn as a water droplet: a clear body with a darker refracting rim, a sharp highlight at the
 * top left and light gathering inside along the bottom. It squishes and jiggles like water when touched.
 *
 * Listening fills the drop with blue and live white bars, so it reads over any app; writing adds a spinning blue
 * comet ring. [dark] lightens the rim for dark screens.
 */
class DropletView(context: Context) : View(context) {
    enum class Mode { IDLE, LISTENING, PROCESSING }

    var mode = Mode.IDLE
        set(value) {
            // A small bounce whenever the drop changes what it's doing.
            if (field != value) pressVelocity -= 3f
            field = value
        }
    var levelProvider: () -> Float = { 0f }
    var dark = false
    var squeezed = false

    private val startedAt = SystemClock.uptimeMillis()
    private var lastFrame = 0f
    private var level = 0f
    private var listen = 0f
    private var processing = 0f
    private var spin = 0f
    private var press = 0f
    private var pressVelocity = 0f
    private val bars = FloatArray(5)

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val path = Path()
    private val matrix = Matrix()
    private val oval = RectF()
    private val mic = ContextCompat.getDrawable(context, R.drawable.ic_stat_mic)?.mutate()

    init {
        setLayerType(LAYER_TYPE_HARDWARE, null)
    }

    override fun onDraw(canvas: Canvas) {
        val now = (SystemClock.uptimeMillis() - startedAt) / 1000f
        val dt = (now - lastFrame).coerceIn(0f, 0.1f)
        lastFrame = now
        step(dt)

        val water = if (dark) NIGHT else DAY
        fun tone(pick: (Water) -> Int) = ColorUtils.blendARGB(pick(water), pick(BLUE), listen)

        val cx = width / 2f
        val cy = height / 2f
        val r = min(width, height) * 0.30f
        val ripple = 0.012f + listen * 0.008f + level * 0.07f

        val squish = canvas.save()
        canvas.scale(1 + press * 0.07f, 1 - press * 0.07f, cx, cy)
        outline(cx, cy, r, now, ripple)

        // Soft shadow peeking out below; kept out of the clear body so the water stays clean.
        canvas.save()
        canvas.clipOutPath(path)
        val sy = cy + r * 0.32f
        paint.shader = RadialGradient(
            cx + r * 0.06f, sy, r * 1.15f,
            intArrayOf(tone { it.shadow }, Color.TRANSPARENT),
            floatArrayOf(0.55f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx + r * 0.06f, sy, r * 1.15f, paint)
        canvas.restore()

        // Body: clear in the middle, thicker toward the rim where the water bends the most light.
        paint.shader = RadialGradient(
            cx, cy + r * 0.08f, r * (1.06f + ripple),
            intArrayOf(tone { it.center }, tone { it.mid }, tone { it.rim }, tone { it.rimOuter }),
            floatArrayOf(0f, 0.55f, 0.86f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawPath(path, paint)

        canvas.save()
        canvas.clipPath(path)
        // Light refracted through the drop gathers along the bottom, opposite the highlight.
        val gx = cx + r * 0.16f
        val gy = cy + r * 0.66f
        paint.shader = RadialGradient(gx, gy, r * 0.72f, tone { it.caustic }, Color.TRANSPARENT, Shader.TileMode.CLAMP)
        canvas.drawCircle(gx, gy, r * 0.72f, paint)
        // Soft reflection of the sky across the top.
        oval.set(cx - r * 0.66f, cy - r * 0.92f, cx + r * 0.52f, cy - r * 0.14f)
        paint.shader = LinearGradient(
            0f, oval.top, 0f, oval.bottom,
            tone { it.sheen }, Color.TRANSPARENT,
            Shader.TileMode.CLAMP,
        )
        canvas.drawOval(oval, paint)
        canvas.restore()

        // Hairline rim: catches the light at the top left, darkens toward the bottom right.
        stroke.shader = LinearGradient(
            cx - r, cy - r, cx + r, cy + r,
            tone { it.rimLight }, tone { it.rimDark },
            Shader.TileMode.CLAMP,
        )
        stroke.strokeWidth = r * 0.04f
        canvas.drawPath(path, stroke)
        stroke.shader = null

        drawGlyph(canvas, cx, cy, r, dt, now, tone { it.glyph })
        drawHighlights(canvas, cx, cy, r)
        canvas.restoreToCount(squish)

        if (processing > 0.01f) drawRing(canvas, cx, cy, r, if (dark) NIGHT.accent else DAY.accent)

        paint.shader = null
        if (isShown) postInvalidateOnAnimation()
    }

    /** The mic at rest and while writing; live bars while listening. */
    private fun drawGlyph(canvas: Canvas, cx: Float, cy: Float, r: Float, dt: Float, now: Float, color: Int) {
        if (listen < 0.99f && mic != null) {
            val s = (r * 0.6f).toInt()
            mic.setBounds((cx - s / 2).toInt(), (cy - s / 2).toInt(), (cx + s / 2).toInt(), (cy + s / 2).toInt())
            mic.setTint(withAlpha(color, 1 - listen))
            mic.draw(canvas)
        }
        if (listen > 0.01f) {
            val barWidth = r * 0.14f
            val gap = r * 0.11f
            val maxHeight = r * 0.95f
            val left = cx - (bars.size * barWidth + (bars.size - 1) * gap) / 2
            paint.shader = null
            paint.color = withAlpha(Color.WHITE, listen)
            for (i in bars.indices) {
                // Each bar wobbles on its own so the group moves like a voice, not a single meter.
                val shape = 0.55f + 0.45f * sin(now * 9f + i * 1.3f)
                val target = (0.18f + level * shape).coerceIn(0.18f, 1f)
                bars[i] += (target - bars[i]) * min(1f, dt * if (target > bars[i]) 20f else 6f)
                val h = maxHeight * bars[i]
                val x = left + i * (barWidth + gap)
                oval.set(x, cy - h / 2, x + barWidth, cy + h / 2)
                canvas.drawRoundRect(oval, barWidth / 2, barWidth / 2, paint)
            }
        }
    }

    /** A crisp window highlight at the top left and a small glint on the opposite rim. */
    private fun drawHighlights(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        val hx = cx - r * 0.42f
        val hy = cy - r * 0.5f
        canvas.save()
        canvas.rotate(-38f, hx, hy)
        canvas.scale(1f, 0.5f, hx, hy)
        paint.shader = RadialGradient(
            hx, hy, r * 0.2f,
            intArrayOf(0xF2FFFFFF.toInt(), 0xB3FFFFFF.toInt(), Color.TRANSPARENT),
            floatArrayOf(0f, 0.45f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(hx, hy, r * 0.2f, paint)
        canvas.restore()

        val gx = cx + r * 0.5f
        val gy = cy + r * 0.5f
        paint.shader = RadialGradient(
            gx, gy, r * 0.09f,
            0xB3FFFFFF.toInt(), Color.TRANSPARENT,
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(gx, gy, r * 0.09f, paint)
        paint.shader = null
    }

    /** Writing: a comet arc that fades out behind its head, spinning around the drop. */
    private fun drawRing(canvas: Canvas, cx: Float, cy: Float, r: Float, accent: Int) {
        val ring = r * 1.22f
        val start = (spin * 140f) % 360f
        val sweep = 130f
        val color = withAlpha(accent, processing)
        stroke.shader = SweepGradient(
            cx, cy,
            intArrayOf(Color.TRANSPARENT, color, Color.TRANSPARENT),
            floatArrayOf(0f, sweep / 360f, sweep / 360f + 0.001f),
        ).apply {
            matrix.setRotate(start, cx, cy)
            setLocalMatrix(matrix)
        }
        stroke.strokeWidth = r * 0.1f
        oval.set(cx - ring, cy - ring, cx + ring, cy + ring)
        canvas.drawArc(oval, start, sweep, false, stroke)
        stroke.shader = null
    }

    private fun step(dt: Float) {
        val target = if (mode == Mode.LISTENING) levelProvider().coerceIn(0f, 1f) else 0f
        level += (target - level) * min(1f, dt * if (target > level) 18f else 4f)
        listen += ((if (mode == Mode.LISTENING) 1f else 0f) - listen) * min(1f, dt * 7f)
        processing += ((if (mode == Mode.PROCESSING) 1f else 0f) - processing) * min(1f, dt * 4f)
        spin += dt * 2.4f

        // Squeeze on a spring, so the drop overshoots and jiggles back like water. Small fixed steps keep it stable.
        val pressTarget = if (squeezed) 1f else 0f
        var left = dt
        while (left > 0f) {
            val h = min(left, 1 / 240f)
            pressVelocity += ((pressTarget - press) * 420f - pressVelocity * 13f) * h
            press += pressVelocity * h
            left -= h
        }
    }

    /** A circle with a slow surface wobble that grows with the voice. */
    private fun outline(cx: Float, cy: Float, radius: Float, t: Float, ripple: Float) {
        path.reset()
        val points = 96
        for (i in 0..points) {
            val a = i / points.toFloat() * 2 * Math.PI.toFloat()
            val wobble = sin(2 * a + t * 1.1f) + 0.6f * sin(3 * a - t * 1.7f + 1.1f) + 0.35f * sin(5 * a + t * 2.9f - 0.7f)
            val r = radius * (1 + ripple * wobble / 1.95f)
            val x = cx + cos(a) * r
            val y = cy + sin(a) * r
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        postInvalidateOnAnimation()
    }

    private class Water(
        val center: Int,
        val mid: Int,
        val rim: Int,
        val rimOuter: Int,
        val caustic: Int,
        val sheen: Int,
        val rimLight: Int,
        val rimDark: Int,
        val shadow: Int,
        val glyph: Int,
        val accent: Int,
    )

    private companion object {
        /** Clear water for light screens: the dark rim is what keeps it visible over white. */
        val DAY = Water(
            center = 0x14E8F1FF,
            mid = 0x1F9FB4D0,
            rim = 0x6B5B708F,
            rimOuter = 0xA0374A66.toInt(),
            caustic = 0xD9FFFFFF.toInt(),
            sheen = 0x8CFFFFFF.toInt(),
            rimLight = 0xB3FFFFFF.toInt(),
            rimDark = 0x9924324A.toInt(),
            shadow = 0x381E283C,
            glyph = 0xB31F2A3D.toInt(),
            accent = 0xFF0A6CDB.toInt(),
        )

        /** Clear water for dark screens: the rim catches light instead. */
        val NIGHT = Water(
            center = 0x0DFFFFFF,
            mid = 0x1AB4C8E6,
            rim = 0x4DC8D8F0,
            rimOuter = 0x8CDCE6F5.toInt(),
            caustic = 0x99FFFFFF.toInt(),
            sheen = 0x66FFFFFF,
            rimLight = 0xA6FFFFFF.toInt(),
            rimDark = 0x33FFFFFF,
            shadow = 0x80000000.toInt(),
            glyph = 0xE6FFFFFF.toInt(),
            accent = 0xFF5AA2FF.toInt(),
        )

        /** Listening: the drop fills with blue so it reads over any app. */
        val BLUE = Water(
            center = 0xE65AA8FF.toInt(),
            mid = 0xF0177CEB.toInt(),
            rim = 0xFA0A62C9.toInt(),
            rimOuter = 0xFF06428F.toInt(),
            caustic = 0xA6B8E0FF.toInt(),
            sheen = 0x8CFFFFFF.toInt(),
            rimLight = 0xCCFFFFFF.toInt(),
            rimDark = 0x9903306B.toInt(),
            shadow = 0x590A3C8C,
            glyph = Color.WHITE,
            accent = 0xFF0A6CDB.toInt(),
        )

        fun withAlpha(color: Int, a: Float) =
            ColorUtils.setAlphaComponent(color, (Color.alpha(color) * a.coerceIn(0f, 1f)).toInt())
    }
}
