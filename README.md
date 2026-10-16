# PocketFlow

Open-source voice dictation for Android and macOS. Speak anywhere you can type and get clean, finished text: filler words gone, self-corrections applied, names spelled the way you spell them.

- **Cleanup that keeps your voice.** "Let's meet Thursday, no wait, Friday, um, after lunch" becomes "Let's meet Friday after lunch." Questions you dictate are written down, never answered.
- **Learns your vocabulary.** Fix a misheard name right after dictating and PocketFlow remembers it. Names and terms are sent as hints to the speech model, and recurring mishearings become automatic replacements.
- **Fits the app you're in.** Email gets a greeting line and paragraphs, chat stays casual, terminals and code editors keep symbols and flags exact.
- **Walk mode (Android).** Press your Bluetooth headset's button, talk, press again. PocketFlow records through the headset mic, writes up a memo or email draft, and tells you when it's saved. The phone stays in your pocket.
- **Bring your own key.** Uses Groq's free tier by default (Whisper large v3 turbo plus GPT-OSS for cleanup), or any OpenAI-compatible API. No account, no server, no telemetry.

## How you dictate

| | Android | macOS |
|---|---|---|
| Anywhere | Floating mic bubble next to the focused text field | Hold **Right ⌥ Option**, release to insert. Or tap to start, tap again to stop |
| Keyboard | PocketFlow voice keyboard (switch to it from any keyboard) | |
| Shortcuts | Quick Settings tile, notification button, hardware keyboard hotkey (Caps Lock by default) | |
| Hands-free | Walk mode: headset button starts and stops a memo | |

## Setup

1. Get a free API key at [console.groq.com/keys](https://console.groq.com/keys).
2. Install and open PocketFlow, then follow the checklist on the Home tab.

**Android** asks for the microphone, notifications, and the PocketFlow accessibility service, which inserts text into other apps and shows the bubble. The voice keyboard is optional. Turn on **Ready to dictate** to keep PocketFlow running in the background.

**macOS** asks for the microphone and Accessibility, which detects the hotkey and pastes into the frontmost app. PocketFlow keeps running in the menu bar when you close its window.

### Walk mode

Turn on **Walk mode** on the Home tab or from the notification. Then, with a Bluetooth headset connected:

1. Press the headset's play/pause button. You'll hear a beep.
2. Talk. Start with "email to Dana…" or "note for the launch plan…" to shape the result.
3. Press the button again, or set **Stop after silence** in Settings.

You'll hear "Memo saved" (or "Email draft saved"), and a notification lets you share the text. Memos also appear in the History on the Home tab, and their recordings stay on the device.

Android sends headset buttons to the app that last played audio. If music was playing, the button controls the music until PocketFlow plays its next cue.

### Remote desktops (RustDesk)

RustDesk only reacts to real key presses, so PocketFlow types into it key by key through its keyboard, and never leaves the text on the phone's clipboard, where RustDesk would sync it to the remote machine.

1. Enable the PocketFlow keyboard and the accessibility service.
2. Let PocketFlow switch keyboards automatically by granting this once from a computer:
   ```bash
   adb shell pm grant dev.markdid.pocketflow android.permission.WRITE_SECURE_SETTINGS
   ```
3. With a hardware keyboard, hold **Caps Lock**, speak, and release. Double-tap it to keep listening hands-free. Other hotkeys are in Settings.

Optional: `tools/pocketflow-keyinject.sh` relays real Cmd shortcuts through RustDesk over adb.

## Privacy

- Audio goes only to the API you configure, and is deleted after transcription. Memo recordings stay on your device until you delete them.
- Your API key is stored in the Android Keystore or the macOS keychain.
- After inserting text, PocketFlow watches that field for up to a minute so it can learn from corrections. Only the changed words, with a few words of context, are sent for review. Password fields are skipped.
- History, vocabulary, and settings are local JSON files in the app's private storage.

## How it works

```
audio ─▶ Whisper (vocabulary as hints) ─▶ replacement rules ─▶ cleanup LLM (style for the app) ─▶ insert
                                                                                        │
              vocabulary ◀── LLM review ◀── word diff ◀── field text a minute later ◀────┘
```

The pipeline is shared Dart code in `lib/dictation/`. Platform code records audio and delivers text:

- **Android** (`android/app/src/main/kotlin`): a foreground service records, optionally through the headset's call-audio link, and runs the Dart pipeline in a headless Flutter engine. Text reaches apps through the accessibility service, the keyboard, or key events for remote desktops.
- **macOS** (`macos/Runner/MainFlutterWindow.swift`): a global key monitor, an audio recorder, a pasteboard-and-Cmd+V paste, and Accessibility reads of the focused field.

## Development

```bash
cp .env.example .env   # add GROQ_API_KEY so debug builds skip the key setup
make run               # or: flutter run -d macos
make check             # format, analyze, tests
```

See `AGENTS.md` and `docs/new-feature-guidelines.md` for the project conventions.

## Credits

The correction-learning diff, prompt budget, and cleanup prompts draw on [OpenWhispr](https://github.com/OpenWhispr/openwhispr) and [FreeFlow](https://github.com/zachlatta/freeflow), both MIT licensed. See `NOTICE`.
