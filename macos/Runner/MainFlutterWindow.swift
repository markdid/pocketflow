import AVFoundation
import ApplicationServices
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var bridge: DesktopBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    bridge = DesktopBridge(messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}

/// Native side of desktop dictation: the global hold-to-talk key (Right Option), recording, pasting into the
/// frontmost app, reading the focused field for correction learning, and the menu bar icon. Dart runs the pipeline.
final class DesktopBridge: NSObject, FlutterStreamHandler {
  private static let hotkeyCode: UInt16 = 61  // Right Option

  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private var sink: FlutterEventSink?
  private var recorder: AVAudioRecorder?
  private var monitors: [Any] = []
  private var hotkeyHeld = false
  private var statusItem: NSStatusItem?

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    channel = FlutterMethodChannel(name: "pocketflow/desktop", binaryMessenger: messenger)
    self.window = window
    super.init()
    FlutterEventChannel(name: "pocketflow/desktop_events", binaryMessenger: messenger).setStreamHandler(self)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    installHotkeyMonitors()
    installStatusItem()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "permissions":
      result([
        "accessibility": AXIsProcessTrusted(),
        "microphone": AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
      ])
    case "requestAccessibility":
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
      result(AXIsProcessTrustedWithOptions(options))
      // Global key monitors only start working once trust is granted; re-arm them a little later.
      DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.installHotkeyMonitors() }
    case "requestMicrophone":
      AVCaptureDevice.requestAccess(for: .audio) { granted in DispatchQueue.main.async { result(granted) } }
    case "startRecording":
      result(startRecording(path: args["path"] as? String ?? ""))
    case "stopRecording":
      result(stopRecording())
    case "frontmostApp":
      result(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    case "paste":
      paste(args["text"] as? String ?? "")
      result(nil)
    case "focusedText":
      result(focusedText())
    case "setStatus":
      setStatus(args["state"] as? String ?? "idle")
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Hotkey

  private func installHotkeyMonitors() {
    monitors.forEach(NSEvent.removeMonitor)
    monitors = []
    let flags: (NSEvent) -> Void = { [weak self] event in self?.handleFlags(event) }
    let keys: (NSEvent) -> Void = { [weak self] _ in
      // Option+letter is a typing shortcut, not dictation.
      if self?.hotkeyHeld == true { self?.sink?(["type": "hotkeyCancel"]) }
    }
    if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags) { monitors.append(global) }
    if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keys) { monitors.append(global) }
    if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { flags($0); return $0 }) {
      monitors.append(local)
    }
  }

  private func handleFlags(_ event: NSEvent) {
    guard event.keyCode == Self.hotkeyCode else { return }
    let down = event.modifierFlags.contains(.option)
    guard down != hotkeyHeld else { return }
    hotkeyHeld = down
    sink?(["type": "hotkey", "down": down])
  }

  // MARK: Recording

  private func startRecording(path: String) -> Bool {
    recorder?.stop()
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 16_000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
    ]
    guard let recorder = try? AVAudioRecorder(url: URL(fileURLWithPath: path), settings: settings),
      recorder.record()
    else { return false }
    self.recorder = recorder
    NSSound(named: "Tink")?.play()
    return true
  }

  /// Returns the recording's length in milliseconds.
  private func stopRecording() -> Int {
    guard let recorder = recorder else { return 0 }
    let millis = Int(recorder.currentTime * 1000)
    recorder.stop()
    self.recorder = nil
    NSSound(named: "Pop")?.play()
    return millis
  }

  // MARK: Text

  /// Pastes through the clipboard, then puts the user's clipboard back.
  private func paste(_ text: String) {
    let pasteboard = NSPasteboard.general
    let previous = pasteboard.string(forType: .string)
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    let ours = pasteboard.changeCount

    let source = CGEventSource(stateID: .combinedSessionState)
    let vKey: CGKeyCode = 9
    let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
    let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
    down?.flags = .maskCommand
    up?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      guard pasteboard.changeCount == ours, let previous = previous else { return }
      pasteboard.clearContents()
      pasteboard.setString(previous, forType: .string)
    }
  }

  /// Text of the focused field in the frontmost app, or nil (no field, password field, or not readable).
  private func focusedText() -> String? {
    let system = AXUIElementCreateSystemWide()
    var focused: CFTypeRef?
    guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
      let element = focused
    else { return nil }
    let axElement = element as! AXUIElement
    var role: CFTypeRef?
    AXUIElementCopyAttributeValue(axElement, kAXSubroleAttribute as CFString, &role)
    if (role as? String) == (kAXSecureTextFieldSubrole as String) { return nil }
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &value) == .success else { return nil }
    return value as? String
  }

  // MARK: Menu bar

  private func installStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    menu.addItem(withTitle: "Open PocketFlow", action: #selector(showWindow), keyEquivalent: "").target = self
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit PocketFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    item.menu = menu
    statusItem = item
    setStatus("idle")
  }

  private func setStatus(_ state: String) {
    let symbol: String
    switch state {
    case "listening": symbol = "mic.fill"
    case "transcribing": symbol = "ellipsis.circle"
    default: symbol = "mic"
    }
    statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "PocketFlow")
    statusItem?.button?.contentTintColor = state == "listening" ? .systemRed : nil
  }

  @objc private func showWindow() {
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }
}
