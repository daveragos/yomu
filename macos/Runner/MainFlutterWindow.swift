import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Draw the app under a transparent title bar, so the sidebar runs to the
    // top edge with the traffic lights on it. Flutter leaves room for the
    // bar via PlatformCaps.titleBarInset.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    // First launch: room for the sidebar plus a column of content. Narrower
    // than ~840pt the app switches to its phone layout, which still works
    // down to the minimum size.
    self.setContentSize(NSSize(width: 1280, height: 820))
    self.contentMinSize = NSSize(width: 400, height: 600)
    self.center()
    // Later launches reopen at the size and position the user left it.
    self.setFrameAutosaveName("YomuMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)
    (NSApplication.shared.delegate as? AppDelegate)?.listenForOpenFiles(
      on: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
