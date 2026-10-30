package dev.markdid.pocketflow.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** One button: tap, speak, tap. The latest memo's progress and text show underneath. */
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

private val Red = Color(0xFFE5483C)
private val Housing = Color(0xFF2A2C30)
private val Muted = Color(0xFFA4A9B2)

@Composable
private fun WatchScreen(status: WatchStatus, onRecord: () -> Unit) {
    val list = rememberScalingLazyListState(initialCenterItemIndex = 0)
    Scaffold(timeText = { TimeText() }) {
        ScalingLazyColumn(state = list, modifier = Modifier.fillMaxSize()) {
            item { RecordButton(recording = status.recordingSince != null, onClick = onRecord) }
            item { StatusLine(status) }
            val last = status.last
            if (status.recordingSince == null && last != null && last.phase in setOf(MemoPhase.Done, MemoPhase.Failed)) {
                item {
                    Text(
                        text = last.text.ifEmpty { "No speech found" },
                        color = if (last.phase == MemoPhase.Failed) Red else Color.White,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun RecordButton(recording: Boolean, onClick: () -> Unit) {
    val dot by animateDpAsState(if (recording) 22.dp else 28.dp, label = "dot")
    val corner by animateDpAsState(if (recording) 5.dp else 14.dp, label = "corner")
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(72.dp)
            .clip(CircleShape)
            .background(Housing)
            .clickable(onClick = onClick)
            .semantics { contentDescription = if (recording) "Stop recording" else "Record" },
    ) {
        Box(Modifier.size(dot).clip(RoundedCornerShape(corner)).background(Red))
    }
}

@Composable
private fun StatusLine(status: WatchStatus) {
    val since = status.recordingSince
    val text = when {
        since != null -> elapsed(since)
        status.last?.phase == MemoPhase.Queued || status.waiting > 0 ->
            if (status.phoneReachable) "Sending…" else "Waiting for phone · ${status.waiting}"
        status.last?.phase == MemoPhase.Writing -> "Writing…"
        else -> ""
    }
    Text(text = text, color = if (since != null) Color.White else Muted, textAlign = TextAlign.Center)
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
