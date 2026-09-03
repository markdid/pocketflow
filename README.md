# PocketFlow

Personal Wispr Flow–style voice dictation for Android, built for **RustDesk** + Bluetooth keyboard.

## Hotkeys

| Shortcut | Notes |
|---|---|
| **Caps Lock** (default) | Hold to talk, release to finish. Double-tap to latch. |
| Ctrl+Shift+Space | Chord alternative (no Alt). |
| Ctrl+Alt+Space | Alt is swallowed so RustDesk crosshair shouldn’t trigger. |

## RustDesk

1. Enable PocketFlow Accessibility.
2. Grant IME switching (one-time from a computer):

```bash
adb shell pm grant com.pocketflow.app android.permission.WRITE_SECURE_SETTINGS
adb shell ime set com.pocketflow.app/.ime.PocketFlowImeService
```

3. Arm PocketFlow (it switches to PocketFlow Keyboard and types key-events into the remote).
4. Hold **Caps Lock**, speak, release.

Fallback: transcript is copied — in RustDesk use **Actions → Send clipboard keystrokes**.

## Build / install

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Put `GROQ_API_KEY` in `.env` (gitignored); debug builds bake it in.
