package dev.markdid.pocketflow.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.TimeTextDefaults
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The phone app's orb: tap, speak, tap. The latest memo's progress and text show underneath. */
class MainActivity : ComponentActivity() {
    private val requestPermissions =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
            if (granted[Manifest.permission.RECORD_AUDIO] == true) RecordingService.toggle(this)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val status by WatchStore.status.collectAsState()
            MaterialTheme { WatchScreen(status, onRecord = ::record) }
        }
    }

    override fun onResume() {
        super.onResume()
        lifecycleScope.launch { PhoneSync.flush(this@MainActivity) }
    }

    private fun record() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            RecordingService.toggle(this)
            return
        }
        requestPermissions.launch(
            buildList {
                add(Manifest.permission.RECORD_AUDIO)
                if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS)
            }.toTypedArray(),
        )
    }
}

@Composable
private fun WatchScreen(status: WatchStatus, onRecord: () -> Unit) {
    val list = rememberScalingLazyListState(initialCenterItemIndex = 0)
    val since = status.recordingSince
    val last = status.last
    val queued = last?.phase == MemoPhase.Queued || status.waiting > 0
    val writing = since == null && (last?.phase == MemoPhase.Writing || (queued && status.phoneReachable))
    val title = when {
        since != null -> "Listening…"
        queued && !status.phoneReachable -> "Waiting for phone"
        writing -> "Writing…"
        last?.phase == MemoPhase.Failed -> "Hmm."
        else -> "Tap to speak"
    }
    val subtitle = when {
        since != null -> elapsed(since)
        queued && !status.phoneReachable && status.waiting > 1 -> "${status.waiting} queued"
        last?.phase == MemoPhase.Failed -> last.text
        last?.phase == MemoPhase.Done && last.text.isEmpty() -> "No speech found"
        else -> ""
    }
    val memo = last?.text?.takeIf { since == null && !writing && last.phase == MemoPhase.Done && it.isNotEmpty() }

    Scaffold(
        modifier = Modifier.background(Pearl.background),
        timeText = { TimeText(timeTextStyle = TimeTextDefaults.timeTextStyle(color = Pearl.textMuted)) },
    ) {
        ScalingLazyColumn(state = list, modifier = Modifier.fillMaxSize().background(Pearl.background)) {
            item {
                VoiceOrb(
                    mode = when {
                        since != null -> OrbMode.Listening
                        writing -> OrbMode.Processing
                        else -> OrbMode.Idle
                    },
                    level = { RecordingService.levelSource?.invoke() ?: 0f },
                    label = if (since != null) "Finish recording" else "Start recording",
                    onClick = onRecord,
                    modifier = Modifier.size(124.dp),
                )
            }
            item { Text(title, style = PearlType.display(20), textAlign = TextAlign.Center) }
            if (subtitle.isNotEmpty()) {
                item {
                    Text(
                        subtitle,
                        style = if (since != null) {
                            PearlType.mono(13f)
                        } else {
                            PearlType.geist(13f, color = if (last?.phase == MemoPhase.Failed) Pearl.danger else Pearl.textMuted)
                        },
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 12.dp),
                    )
                }
            }
            if (memo != null) {
                item {
                    Text(
                        memo,
                        style = PearlType.geist(14f),
                        modifier = Modifier
                            .padding(top = 6.dp)
                            .fillMaxWidth()
                            .shadow(1.dp, RoundedCornerShape(18.dp))
                            .background(Pearl.surface, RoundedCornerShape(18.dp))
                            .padding(horizontal = 14.dp, vertical = 12.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun elapsed(since: Long): String {
    var now by remember { mutableLongStateOf(SystemClock.elapsedRealtime()) }
    LaunchedEffect(since) {
        while (true) {
            now = SystemClock.elapsedRealtime()
            delay(500)
        }
    }
    val seconds = ((now - since) / 1000).coerceAtLeast(0)
    return "%d:%02d".format(seconds / 60, seconds % 60)
}
