package dev.markdid.pocketflow.accessibility

import dev.markdid.pocketflow.accessibility.PocketFlowAccessibilityService.Companion.shouldShowBubble
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BubbleVisibilityTest {
    private fun show(
        enabled: Boolean = true,
        hardwareKeyboard: Boolean = false,
        softKeyboardVisible: Boolean = true,
        focusEditable: Boolean = false,
        focusPassword: Boolean = false,
        ownApp: Boolean = false,
        pocketFlowKeyboard: Boolean = false,
    ) = shouldShowBubble(
        enabled = enabled,
        hardwareKeyboard = hardwareKeyboard,
        softKeyboardVisible = softKeyboardVisible,
        focusEditable = focusEditable,
        focusPassword = focusPassword,
        ownApp = ownApp,
        pocketFlowKeyboard = pocketFlowKeyboard,
    )

    @Test
    fun `shows with the keyboard open even when no editable field is reported`() = assertTrue(show())

    @Test
    fun `hides when the keyboard is closed`() = assertFalse(show(softKeyboardVisible = false, focusEditable = true))

    @Test
    fun `hides on password fields`() = assertFalse(show(focusPassword = true))

    @Test
    fun `hides in PocketFlow itself`() = assertFalse(show(ownApp = true))

    @Test
    fun `hides when the PocketFlow keyboard is in use`() = assertFalse(show(pocketFlowKeyboard = true))

    @Test
    fun `hides when the bubble is off or dictation is disarmed`() = assertFalse(show(enabled = false))

    @Test
    fun `hardware keyboard needs an editable field`() {
        assertTrue(show(hardwareKeyboard = true, softKeyboardVisible = false, focusEditable = true))
        assertFalse(show(hardwareKeyboard = true, softKeyboardVisible = false, focusEditable = false))
    }
}
