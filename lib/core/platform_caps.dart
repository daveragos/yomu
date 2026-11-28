import 'dart:io' show Platform;

/// What the platform Yomu is running on can do.
///
/// Several plugins only exist on some platforms, and calling one where it is
/// not implemented throws `MissingPluginException`. Check here before using
/// one, so each platform rule lives in one place.
abstract final class PlatformCaps {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Books opened or shared from other apps (`receive_sharing_intent`).
  ///
  /// Android only: on iOS the plugin needs a share extension, which Yomu
  /// doesn't have. iPhones hand books over through [hasOpenFilesChannel].
  static bool get hasShareIntents => Platform.isAndroid;

  /// Books the system asks Yomu to open, through the `yomu/open_files`
  /// channel: Finder's or the file manager's Open With on macOS and Linux,
  /// "Open in Yomu" on iOS.
  static bool get hasOpenFilesChannel =>
      Platform.isMacOS || Platform.isLinux || Platform.isIOS;

  /// The app keeps its own copy of every book it imports, instead of
  /// pointing at the picked file. Desktops need this for the sandbox (see
  /// `LibraryFiles`); on iOS a picked or opened file is a temporary copy
  /// that the system may delete.
  static bool get keepsOwnBookCopies => isDesktop || Platform.isIOS;

  /// Runtime permission prompts and the app-settings shortcut
  /// (`permission_handler`).
  static bool get hasPermissionHandler => isMobile;

  /// Local notifications are set up for this platform. Windows needs its
  /// own initialization settings before it can be enabled.
  static bool get hasLocalNotifications =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux;

  /// Height of the macOS title bar that the app draws underneath. The window
  /// has a transparent title bar (see `MainFlutterWindow.swift`), so content
  /// must leave this much room at the top for the traffic-light buttons and
  /// for dragging the window. Zero elsewhere.
  static double get titleBarInset => Platform.isMacOS ? 28 : 0;
}
