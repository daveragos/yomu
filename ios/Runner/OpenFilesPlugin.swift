import Flutter
import UIKit

/// Books other apps hand to Yomu: "Open in Yomu" or "Copy to Yomu" from the
/// share sheet in Files, Telegram, Mail or Safari, for the document types
/// declared in Info.plist. The iPhone counterpart of macOS's Finder Open With,
/// answering the same `yomu/open_files` channel (see `DesktopOpenFiles`).
///
/// iOS hands over a URL that is only readable for a while: a copy in
/// `tmp/<bundle id>-Inbox`, or a security-scoped file in another app's storage. Each
/// one is copied into the caches folder, the way Android's file_picker hands
/// over a cache copy, and the library then keeps its own copy and removes this
/// one (see `LibraryFiles.keep` and `FileStorageService.deleteCachedCopy`).
final class OpenFilesPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private var channel: FlutterMethodChannel?

  /// Files that arrived before Flutter asked for them.
  private var pending: [String] = []

  /// Whether Flutter has asked for pending files, so later ones can be sent
  /// straight away.
  private var flutterIsListening = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = OpenFilesPlugin()
    let channel = FlutterMethodChannel(
      name: "yomu/open_files", binaryMessenger: registrar.messenger())
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takePending":
      flutterIsListening = true
      result(pending)
      pending = []
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // A cold launch: Yomu was started to open the files.
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts else { return false }
    return receive(contexts)
  }

  // Yomu was already running.
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return receive(URLContexts)
  }

  private func receive(_ contexts: Set<UIOpenURLContext>) -> Bool {
    let paths = contexts.map(\.url).filter(\.isFileURL).compactMap(copyToCaches)
    if paths.isEmpty { return false }
    if flutterIsListening, let channel {
      channel.invokeMethod("open", arguments: paths)
    } else {
      pending.append(contentsOf: paths)
    }
    return true
  }

  /// Copies [url] to `Caches/open_in/<unique>/<name>` and returns that path,
  /// or nil when it can't be read.
  private func copyToCaches(_ url: URL) -> String? {
    let fileManager = FileManager.default
    guard
      let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    let folder = caches
      .appendingPathComponent("open_in", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let destination = folder.appendingPathComponent(url.lastPathComponent)

    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    do {
      try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
      try fileManager.copyItem(at: url, to: destination)
    } catch {
      NSLog("Yomu could not take the opened file \(url.lastPathComponent): \(error)")
      try? fileManager.removeItem(at: folder)
      return nil
    }

    // The copy iOS made for Yomu (in tmp/<bundle id>-Inbox, or Documents/Inbox
    // on older versions) isn't needed any more. Files in other apps' storage
    // are left alone.
    let inboxes = [
      fileManager.temporaryDirectory,
      fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Inbox", isDirectory: true),
    ].compactMap { $0 }
    if inboxes.contains(where: { url.isInside($0) }) {
      try? fileManager.removeItem(at: url)
    }
    return destination.path
  }
}

private extension URL {
  /// Whether this file is somewhere inside [folder]. Resolves symlinks first,
  /// since iOS reports the same folder as both /var/... and /private/var/....
  func isInside(_ folder: URL) -> Bool {
    let path = resolvingSymlinksInPath().path
    let folderPath = folder.resolvingSymlinksInPath().path
    return path.hasPrefix(folderPath.hasSuffix("/") ? folderPath : folderPath + "/")
  }
}
