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

    // Let the aurora run edge to edge under a transparent title bar.
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)
    isMovableByWindowBackground = true
    backgroundColor = NSColor(red: 0.024, green: 0.024, blue: 0.039, alpha: 1)
    minSize = NSSize(width: 420, height: 640)
    setContentSize(NSSize(width: 460, height: 820))
    center()

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
  private var levelTimer: Timer?
  private let hud = DictationHUD()

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
    recorder.isMeteringEnabled = true
    levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      guard let recorder = self?.recorder else { return }
      recorder.updateMeters()
      let amplitude = pow(10, Double(recorder.averagePower(forChannel: 0)) / 20)
      let level = min(1, amplitude * 4)
      self?.hud.level = CGFloat(level)
      self?.sink?(["type": "level", "value": level])
    }
    NSSound(named: "Tink")?.play()
    return true
  }

  /// Returns the recording's length in milliseconds.
  private func stopRecording() -> Int {
    guard let recorder = recorder else { return 0 }
    let millis = Int(recorder.currentTime * 1000)
    levelTimer?.invalidate()
    levelTimer = nil
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
    hud.show(state: state)
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

/// Floating pill at the bottom of the screen while dictating: a live aurora waveform while listening, a shimmer
/// while writing. Never takes focus or clicks, so the app you're typing into stays active.
final class DictationHUD {
  private var panel: NSPanel?
  private let wave = HUDWaveView(frame: NSRect(x: 0, y: 0, width: 172, height: 46))
  private var hideWork: DispatchWorkItem?

  var level: CGFloat {
    get { wave.level }
    set { wave.level = newValue }
  }

  func show(state: String) {
    hideWork?.cancel()
    switch state {
    case "listening", "transcribing":
      wave.processing = state == "transcribing"
      present()
    default:
      let work = DispatchWorkItem { [weak self] in self?.dismiss() }
      hideWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
  }

  private func present() {
    let panel = self.panel ?? makePanel()
    self.panel = panel
    guard let screen = NSScreen.main else { return }
    let size = panel.frame.size
    let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.minY + 28)
    panel.setFrameOrigin(origin)
    if !panel.isVisible {
      panel.alphaValue = 0
      panel.orderFrontRegardless()
      wave.start()
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.18
        panel.animator().alphaValue = 1
      }
    }
  }

  private func dismiss() {
    guard let panel = panel, panel.isVisible else { return }
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.25
      panel.animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      panel.orderOut(nil)
      self?.wave.stop()
    })
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: wave.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

    let blur = NSVisualEffectView(frame: wave.frame)
    blur.material = .hudWindow
    blur.blendingMode = .behindWindow
    blur.state = .active
    blur.wantsLayer = true
    blur.layer?.cornerRadius = wave.frame.height / 2
    blur.layer?.masksToBounds = true
    blur.layer?.borderWidth = 1
    blur.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
    blur.addSubview(wave)
    panel.contentView = blur
    return panel
  }
}

final class HUDWaveView: NSView {
  var level: CGFloat = 0
  var processing = false
  private var history = [CGFloat](repeating: 0, count: 22)
  private var timer: Timer?
  private var phase: CGFloat = 0
  private static let colors: [NSColor] = [
    NSColor(red: 0.48, green: 0.38, blue: 1, alpha: 1),
    NSColor(red: 1, green: 0.31, blue: 0.85, alpha: 1),
    NSColor(red: 1, green: 0.70, blue: 0.28, alpha: 1),
    NSColor(red: 0.21, green: 0.88, blue: 1, alpha: 1),
  ]

  func start() {
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    history = history.map { _ in 0 }
  }

  private func tick() {
    phase += 0.12
    let next = processing ? 0.25 + 0.2 * sin(phase * 1.5) : level
    history.removeFirst()
    history.append(next)
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    let count = history.count
    let barWidth: CGFloat = 3.5
    let gap = (bounds.width - 40 - barWidth * CGFloat(count)) / CGFloat(count - 1)
    let gradient = NSGradient(colors: Self.colors)
    for (index, value) in history.enumerated() {
      // Processing: a soft shimmer travels along the bars instead of the voice.
      let shimmer = processing ? 0.5 + 0.5 * sin(phase * 2 - CGFloat(index) * 0.45) : 1
      let height = max(4, min(bounds.height - 16, 4 + value * (bounds.height - 14))) * (processing ? shimmer : 1)
      let x = 20 + CGFloat(index) * (barWidth + gap)
      let rect = NSRect(x: x, y: (bounds.height - height) / 2, width: barWidth, height: max(4, height))
      let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
      NSGraphicsContext.saveGraphicsState()
      path.addClip()
      gradient?.draw(in: NSRect(x: 20, y: 0, width: bounds.width - 40, height: bounds.height), angle: 0)
      NSGraphicsContext.restoreGraphicsState()
    }
  }
}
