package dev.markdid.pocketflow.wear

import android.graphics.BlurMaskFilter
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

enum class OrbMode { Idle, Listening, Processing }

/** Smoothed animation values, as in the phone's `_OrbFrame`. */
private class OrbFrame {
    var time = 0f
    var level = 0f
    var energy = 0.18f
    var spin = 0f
    var processing = 0f
}

/**
 * The phone's pearl orb (lib/ui/widgets/effects/voice_orb.dart), ported to Compose: it breathes at rest, ripples
 * with [level] and gains a blue halo while listening, and a thin beam circles it while writing.
 */
@Composable
fun VoiceOrb(mode: OrbMode, level: () -> Float, label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val frame = remember { OrbFrame() }
    val currentMode by rememberUpdatedState(mode)
    var tick by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        var start = -1L
        while (true) {
            withFrameNanos { now ->
                if (start < 0) start = now
                val time = (now - start) / 1e9f
                val dt = time - frame.time
                val listening = currentMode == OrbMode.Listening
                val targetLevel = if (listening) level() else 0f
                val targetEnergy = when (currentMode) {
                    OrbMode.Idle -> 0.18f
                    OrbMode.Listening -> 0.45f + targetLevel * 0.55f
                    OrbMode.Processing -> 0.55f
                }
                val levelRate = if (targetLevel > frame.level) 18f else 4f
                val processing = if (currentMode == OrbMode.Processing) 1f else 0f
                frame.time = time
                frame.level += (targetLevel - frame.level) * min(1f, dt * levelRate)
                frame.energy += (targetEnergy - frame.energy) * min(1f, dt * 3)
                frame.spin += dt * (if (currentMode == OrbMode.Processing) 2.4f else 0.35f)
                frame.processing += (processing - frame.processing) * min(1f, dt * 4)
                tick = now
            }
        }
    }
    Canvas(
        modifier
            .semantics { contentDescription = label }
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick),
    ) {
        tick // redraw every frame
        drawOrb(frame)
    }
}

private fun DrawScope.drawOrb(f: OrbFrame) {
    val t = f.time
    val base = size.minDimension * 0.30f * (1 + 0.015f * sin(t * 1.6f))
    // How "live" the orb is: 0 at rest, up to 1 on loud speech. Only this brings in the accent.
    val live = ((f.energy - 0.18f).coerceIn(0f, 1f) / 0.82f) * (1 - f.processing)

    if (live > 0.01f) {
        for ((scale, alpha) in listOf(1.36f + f.level * 0.16f to 0.05f, 1.17f + f.level * 0.1f to 0.10f)) {
            drawCircle(Pearl.accent.copy(alpha = alpha * live), radius = base * scale)
        }
    }

    val ripple = 0.016f + f.energy * 0.02f + f.level * 0.09f
    val shape = blob(center, base, t, ripple)

    // Drop shadow beneath the pearl.
    val shadow = android.graphics.Paint().apply {
        isAntiAlias = true
        color = lerp(Color(0x4A1E283C), Pearl.accent.copy(alpha = 0.35f), live).toArgb()
        maskFilter = BlurMaskFilter(base * 0.22f, BlurMaskFilter.Blur.NORMAL)
    }
    translate(top = base * 0.22f) { drawContext.canvas.nativeCanvas.drawPath(shape.asAndroidPath(), shadow) }

    // Pearl body, lit from the top left.
    drawPath(
        shape,
        Brush.radialGradient(
            0f to Color(0xFFFFFFFF),
            0.3f to Color(0xFFF1F3F6),
            0.68f to Color(0xFFD9DEE6),
            1f to Color(0xFFC4CAD4),
            center = center + Offset(-0.36f * base, -0.44f * base),
            radius = base * 2.3f,
        ),
    )

    // Inner shade along the bottom edge, tinted blue while listening.
    clipPath(shape) {
        val shadeCenter = center + Offset(0f, base * 0.55f)
        drawCircle(
            Brush.radialGradient(
                listOf(lerp(Color(0x40788296), Pearl.accent.copy(alpha = 0.28f), live), Color.Transparent),
                center = shadeCenter,
                radius = base * 1.1f,
            ),
            radius = base * 1.1f,
            center = shadeCenter,
        )
    }

    // Writing: a thin accent beam circling the orb.
    if (f.processing > 0.01f) {
        val radius = base * 1.24f
        rotate(degrees = (f.spin * 1.6f) * 180f / PI.toFloat(), pivot = center) {
            drawArc(
                Brush.sweepGradient(
                    0f to Pearl.accent.copy(alpha = 0f),
                    0.24f to Pearl.accent.copy(alpha = f.processing),
                    center = center,
                ),
                startAngle = 0f,
                sweepAngle = 0.48f * 180f,
                useCenter = false,
                topLeft = center - Offset(radius, radius),
                size = Size(radius * 2, radius * 2),
                style = Stroke(width = base * 0.03f, cap = StrokeCap.Round),
            )
        }
    }
}

private fun blob(center: Offset, radius: Float, t: Float, ripple: Float): Path {
    val points = 120
    return Path().apply {
        for (i in 0..points) {
            val a = i.toFloat() / points * 2 * PI.toFloat()
            val wobble = sin(3 * a + t * 1.7f) + 0.6f * sin(5 * a - t * 2.3f + 1.1f) + 0.35f * sin(8 * a + t * 3.4f - 0.7f)
            val r = radius * (1 + ripple * wobble / 1.95f)
            val x = center.x + cos(a) * r
            val y = center.y + sin(a) * r
            if (i == 0) moveTo(x, y) else lineTo(x, y)
        }
        close()
    }
}
