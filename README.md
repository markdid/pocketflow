# PocketFlow

Open-source voice dictation for Android and macOS. Speak anywhere you can type and get clean, finished text: filler words gone, self-corrections applied, names spelled the way you spell them.

- **Cleanup that keeps your voice.** "Let's meet Thursday, no wait, Friday, um, after lunch" becomes "Let's meet Friday after lunch." Questions you dictate are written down, never answered.
- **Learns your vocabulary.** Fix a misheard name right after dictating and PocketFlow remembers it. Names and terms are sent as hints to the speech model, and recurring mishearings become automatic replacements.
- **Fits the app you're in.** Email gets a greeting line and paragraphs, chat stays casual, terminals and code editors keep symbols and flags exact.
- **Walk mode (Android).** Press your Bluetooth headset's button, talk, press again. PocketFlow records through the headset mic, writes up a memo or email draft, and tells you when it's saved. The phone stays in your pocket.
- **Bring your own key.** Uses Groq's free tier by default (Whisper large v3 turbo plus GPT-OSS for cleanup), or any OpenAI-compatible API. No account, no server, no telemetry.
- **Galaxy Watch companion (optional).** Open the watch app, talk, and the memo lands on your phone.

## Install

**Android:** download `pocketflow.apk` from the [latest release](../../releases/latest) and open it on your phone. For the watch app, grab `pocketflow-watch.apk` too; watches can only install apps over adb.

**Or let Claude do it.** Paste this into [Claude Code](https://claude.com/claude-code) on a computer:

```text
Install PocketFlow (https://github.com/markdid/pocketflow) on my Android phone, and on my Wear OS watch if I
say I have one.

1. Download pocketflow.apk and pocketflow-watch.apk from the latest GitHub release. Install adb if it's missing
   (Homebrew on macOS, winget on Windows, the distro package on Linux).
2. Phone: walk me through turning on Developer options and USB debugging, connect over USB, then
   `adb install -r pocketflow.apk`.
3. Watch (Galaxy Watch 4 or later, or any Wear OS 3+ watch): walk me through Settings > About watch > Software,
   tapping Software version until Developer options turns on, then Developer options > ADB debugging and
   Wireless debugging, with the watch on the same Wi-Fi as this computer. Pair with `adb pair <ip>:<port>` using the
   code under "Pair new device", connect with `adb connect <ip>:<port>`, then
   `adb -s <ip>:<port> install -r pocketflow-watch.apk`. The port changes on every reconnect; `adb mdns services`
   lists the current one.
4. Tell me to open PocketFlow on the phone and follow its Home checklist, then open it on the watch and allow the
   microphone. Turn off the watch's Wireless debugging afterwards to save battery.

Tell me exactly what to tap at each step, wait for me, and check each install succeeded before moving on.
```

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

- Audio goes only to the API you configure, and is deleted after transcription. Memo recordings, and recordings that failed to transcribe (so you can try again), stay on your device until you delete them. Turn on **Keep recordings** in Settings to keep every dictation's audio too.
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

### Releases

Pushing a `v*` tag runs `.github/workflows/release.yml`, which builds `pocketflow.apk` and `pocketflow-watch.apk` and attaches them to a GitHub release. Bump `version:` in `pubspec.yaml` first; both apps use it.

Both APKs are signed with one release key, which must never change: the watch only pairs with a phone app signed by the same key, and Android rejects updates signed by a different one. It lives in two repository secrets, `POCKETFLOW_KEYSTORE_BASE64` (`base64 -i pocketflow-release.jks`) and `POCKETFLOW_KEYSTORE_PASSWORD`, with the key alias `pocketflow`. Local builds sign with the debug key unless `POCKETFLOW_KEYSTORE` and `POCKETFLOW_KEYSTORE_PASSWORD` are set.

## Credits

The correction-learning diff, prompt budget, and cleanup prompts draw on [OpenWhispr](https://github.com/OpenWhispr/openwhispr) and [FreeFlow](https://github.com/zachlatta/freeflow), both MIT licensed. See `NOTICE`.

## License

MIT. See `LICENSE`.
