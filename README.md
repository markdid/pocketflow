# PocketFlow

Personal Wispr Flow–style voice dictation for Android, built for controlling a computer over **RustDesk** with a Bluetooth keyboard.

## Why

Wispr Flow can’t be started from a Bluetooth keyboard shortcut. PocketFlow listens for a global hotkey, records from the phone mic, transcribes with **Groq Whisper** (free tier), and inserts the text into the focused app.

## Hotkeys

| Shortcut | Notes |
|---|---|
| **Ctrl+Alt+Space** (Control+Option+Space) | Reliable. Default. |
| **Fn** | Best-effort. Many BT keyboards never deliver Fn to Android. |
| Mode: Fn or Ctrl+Alt | Tries both (default). |

Press once to start listening, again to stop and insert.

## RustDesk setup

1. Install PocketFlow, grant mic + notifications.
2. Paste your Groq API key (`gsk_…`) and Save.
3. Enable **PocketFlow** under Settings → Accessibility (required for global hotkeys).
4. Enable **PocketFlow Keyboard** under Settings → System → Languages & input → On-screen keyboard, then switch to it while in RustDesk (IME path is what remote sessions forward reliably).
5. Tap **Arm PocketFlow** (keeps a quiet notification alive so hotkeys can start the mic).
6. Focus a text field on the remote machine via RustDesk, press **Ctrl+Alt+Space**, speak, press again.

If auto-insert fails, the transcript is copied to the clipboard.

## Build

```bash
cd pocketflow
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

## Privacy

- API key stored in EncryptedSharedPreferences.
- Audio is written to app cache, uploaded to Groq, then deleted.
- No analytics.
