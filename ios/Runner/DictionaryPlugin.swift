import Flutter
import UIKit

/// Shows a word in iOS's built-in dictionary sheet, the one behind "Look Up".
/// macOS opens its Dictionary app through an `x-dictionary:` link instead,
/// which iOS doesn't have. Answers `yomu/dictionary` (see `SystemDictionary`).
final class DictionaryPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "yomu/dictionary", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(DictionaryPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "show", let term = call.arguments as? String else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let presenter = topViewController() else {
      result(false)
      return
    }
    // When no dictionary is downloaded, the sheet offers to get one.
    presenter.present(UIReferenceLibraryViewController(term: term), animated: true)
    result(true)
  }

  private func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
