import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Files macOS asked Yomu to open (Finder's Open With, a double-click, a
  /// drop on the Dock icon) before the Flutter side started listening.
  private var pendingPaths: [String] = []
  private var openFilesChannel: FlutterMethodChannel?
  private var flutterIsListening = false

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Starts answering Flutter's requests for opened files. Called by the
  /// window as it creates the Flutter view: Dart starts running then, before
  /// applicationDidFinishLaunching, and may ask straight away.
  func listenForOpenFiles(on messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "yomu/open_files", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      // Flutter calls this once it listens, and gets anything that arrived
      // during launch.
      if call.method == "takePending" {
        self.flutterIsListening = true
        result(self.pendingPaths)
        self.pendingPaths.removeAll()
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    openFilesChannel = channel
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    super.application(application, open: urls)
    let paths = urls.filter { $0.isFileURL }.map { $0.path }
    guard !paths.isEmpty else { return }
    if flutterIsListening, let channel = openFilesChannel {
      channel.invokeMethod("open", arguments: paths)
    } else {
      pendingPaths.append(contentsOf: paths)
    }
  }
}
