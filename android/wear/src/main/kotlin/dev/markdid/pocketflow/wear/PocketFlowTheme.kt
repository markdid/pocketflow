package dev.markdid.pocketflow.wear

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

/** The phone app's "Pearl" palette (lib/ui/theme/app_theme_data.dart). Keep the two in step. */
object Pearl {
    val background = Color(0xFFF5F6F8)
    val surface = Color(0xFFFFFFFF)
    val text = Color(0xFF0F1115)
    val textMuted = Color(0xFF5F6672)
    val textFaint = Color(0xFF9AA1AD)
    val accent = Color(0xFF0A6CDB)
    val danger = Color(0xFFC5352B)
}

@OptIn(ExperimentalTextApi::class)
private fun geist(weight: Int) = Font(
    R.font.geist,
    weight = FontWeight(weight),
    variationSettings = FontVariation.Settings(FontVariation.weight(weight)),
)

private val Geist = FontFamily(geist(400), geist(560), geist(640))
private val GeistMono = FontFamily(Font(R.font.geist_mono))

/** The phone's text styles: `AppThemeData.display`, `geist`, and `mono`. */
object PearlType {
    fun display(size: Int) = TextStyle(
        fontFamily = Geist,
        fontWeight = FontWeight(640),
        fontSize = size.sp,
        letterSpacing = (-0.032).em,
        lineHeight = (size * 1.1).sp,
        color = Pearl.text,
    )

    fun geist(size: Float, weight: Int = 400, color: Color = Pearl.text) = TextStyle(
        fontFamily = Geist,
        fontWeight = FontWeight(weight),
        fontSize = size.sp,
        lineHeight = (size * 1.4).sp,
        color = color,
    )

    fun mono(size: Float, color: Color = Pearl.textMuted) =
        TextStyle(fontFamily = GeistMono, fontSize = size.sp, color = color)
}
