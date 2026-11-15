import Cocoa
import FlutterMacOS
import SwiftUI

/// Yomu's celebration toasts on macOS: achievements, finished quests, new
/// levels and new ranks. Each is a small card that floats at the top right
/// of the screen, above other apps and on every Space, whether or not Yomu
/// is in front. It drains a thin timer bar and fades away; hovering pauses
/// the timer and clicking dismisses it. It never takes focus from the app
/// the user is in.
///
/// Flutter shows one with `show` on the `yomu/celebrations` channel (see
/// `lib/services/celebrations.dart`).
final class CelebrationPanels {
  static let shared = CelebrationPanels()

  /// Past this many cards, the oldest leaves early.
  private let maxVisible = 3
  private let spacing: CGFloat = 10
  private let edgeInset: CGFloat = 16

  private var panels: [CelebrationPanel] = []
  private var channel: FlutterMethodChannel?

  func listen(on messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "yomu/celebrations", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show",
            let args = call.arguments as? [String: Any],
            let title = args["title"] as? String,
            let body = args["body"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.show(
        title: title,
        body: body,
        kind: args["kind"] as? String ?? "",
        dark: args["dark"] as? Bool ?? true
      )
      result(nil)
    }
    self.channel = channel
  }

  func show(title: String, body: String, kind: String, dark: Bool) {
    let panel = CelebrationPanel(
      model: CelebrationModel(title: title, body: body, kind: kind, dark: dark)
    ) { [weak self] finished in
      self?.panels.removeAll { $0 === finished }
      self?.layout(animated: true)
    }
    // Newest on top, the way macOS stacks its own banners.
    panels.insert(panel, at: 0)
    if panels.count > maxVisible, let oldest = panels.last {
      oldest.leave()
    }
    layout(animated: true, entering: panel)
  }

  /// Stacks the cards down from the top-right corner of the screen the user
  /// is working on.
  private func layout(animated: Bool, entering: CelebrationPanel? = nil) {
    guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
    let area = screen.visibleFrame
    var top = area.maxY - 12
    for panel in panels where !panel.isLeaving {
      let size = panel.frame.size
      let frame = NSRect(
        x: area.maxX - size.width - edgeInset,
        y: top - size.height,
        width: size.width,
        height: size.height
      )
      top = frame.minY - spacing
      if panel === entering {
        panel.enter(at: frame)
      } else {
        panel.move(to: frame, animated: animated)
      }
    }
  }
}

/// One card's content and timer.
final class CelebrationModel: ObservableObject {
  static let lifetime: TimeInterval = 12

  let title: String
  let body: String
  let kind: String

  /// Whether Yomu is in dark mode; the card matches the app, not macOS.
  let dark: Bool

  /// Runs from 1 (full bar) down to 0 over [lifetime], paused while hovered.
  @Published var remaining: Double = 1
  var isHovered = false
  var onExpired: (() -> Void)?
  var onTapped: (() -> Void)?

  private var timer: Timer?
  private var lastTick = Date()

  init(title: String, body: String, kind: String, dark: Bool) {
    self.title = title
    self.body = body
    self.kind = kind
    self.dark = dark
  }

  var symbol: String {
    switch kind {
    case "achievement": return "trophy"
    case "quest": return "checkmark.circle"
    case "level": return "chart.line.uptrend.xyaxis"
    case "rank": return "rosette"
    default: return "sparkles"
    }
  }

  func start() {
    lastTick = Date()
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      self?.tick()
    }
    // .common keeps the bar moving while menus or scrolling hold the run loop.
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  private func tick() {
    let now = Date()
    let elapsed = now.timeIntervalSince(lastTick)
    lastTick = now
    guard !isHovered else { return }
    remaining = max(0, remaining - elapsed / Self.lifetime)
    if remaining == 0 {
      stop()
      onExpired?()
    }
  }
}

/// A borderless panel that floats above other apps without activating Yomu.
final class CelebrationPanel: NSPanel {
  private static let width: CGFloat = 340

  let model: CelebrationModel
  private let onFinished: (CelebrationPanel) -> Void
  private(set) var isLeaving = false

  init(model: CelebrationModel, onFinished: @escaping (CelebrationPanel) -> Void) {
    self.model = model
    self.onFinished = onFinished
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 80),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    isMovable = false
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    appearance = NSAppearance(named: model.dark ? .darkAqua : .aqua)

    let host = CardHostingView(rootView: CelebrationCard(model: model))
    host.onHoverChange = { [weak model] hovered in model?.isHovered = hovered }
    contentView = host
    setContentSize(NSSize(width: Self.width, height: host.fittingSize.height))

    model.onExpired = { [weak self] in self?.leave() }
    model.onTapped = { [weak self] in self?.leave() }
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  /// Slides in from the right edge and fades up, then starts the timer.
  func enter(at frame: NSRect) {
    setFrame(frame.offsetBy(dx: 24, dy: 0), display: false)
    alphaValue = 0
    orderFrontRegardless()
    invalidateShadow()
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.22
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      animator().setFrame(frame, display: true)
      animator().alphaValue = 1
    }, completionHandler: { [weak self] in
      guard let self = self else { return }
      // A card that appears under the pointer waits until it moves off.
      self.model.isHovered = self.frame.contains(NSEvent.mouseLocation)
      self.model.start()
    })
  }

  func move(to frame: NSRect, animated: Bool) {
    guard animated else {
      setFrame(frame, display: true)
      return
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      animator().setFrame(frame, display: true)
    }
  }

  /// Fades out while shrinking slightly, then closes.
  func leave() {
    guard !isLeaving else { return }
    isLeaving = true
    model.stop()
    let shrunk = frame.insetBy(dx: 8, dy: 4)
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.2
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      animator().setFrame(shrunk, display: true)
      animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      guard let self = self else { return }
      self.orderOut(nil)
      self.close()
      self.onFinished(self)
    })
  }
}

/// Hosts a card's SwiftUI view and reports the pointer entering and leaving
/// it. SwiftUI's own hover tracking only runs while the app is active, but a
/// card floats over whatever app the user is in, so this tracks always.
private final class CardHostingView<Content: View>: NSHostingView<Content> {
  var onHoverChange: ((Bool) -> Void)?
  private var hoverArea: NSTrackingArea?

  /// Lets the first click on a card count even though Yomu isn't active.
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let hoverArea = hoverArea { removeTrackingArea(hoverArea) }
    let area = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    hoverArea = area
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    onHoverChange?(true)
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    onHoverChange?(false)
  }
}

/// The card itself, drawn to match Yomu's surfaces (`YomuColors` in
/// Flutter): a solid panel with a hairline border, an accent icon, and the
/// timer bar along the bottom, light or dark like the app.
private struct CelebrationCard: View {
  @ObservedObject var model: CelebrationModel

  private static func rgb(_ hex: UInt32) -> Color {
    Color(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }

  private var surface: Color { model.dark ? Self.rgb(0x16171D) : Self.rgb(0xFFFFFF) }
  private var accent: Color { model.dark ? Self.rgb(0x2ECC71) : Self.rgb(0x1E9A57) }
  private var secondary: Color { model.dark ? Self.rgb(0x94A3B8) : Self.rgb(0x586273) }
  private var primary: Color { model.dark ? .white : Self.rgb(0x15171C) }
  private var ink: Color { model.dark ? .white : .black }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 12) {
        ZStack {
          Circle().fill(ink.opacity(0.05))
          Image(systemName: model.symbol)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(accent)
        }
        .frame(width: 36, height: 36)

        VStack(alignment: .leading, spacing: 2) {
          Text(model.title)
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundColor(primary)
          Text(model.body)
            .font(.system(size: 12.5))
            .foregroundColor(secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 1)

        Spacer(minLength: 0)
      }
      .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))

      GeometryReader { geometry in
        Rectangle()
          .fill(accent)
          .frame(width: geometry.size.width * model.remaining, height: 2)
      }
      .frame(height: 2)
    }
    .frame(width: 340)
    .background(surface)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(ink.opacity(model.dark ? 0.08 : 0.10), lineWidth: 1)
    )
    .contentShape(Rectangle())
    .onTapGesture { model.onTapped?() }
  }
}
