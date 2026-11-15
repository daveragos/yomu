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
  static bool get hasShareIntents => isMobile;

  /// Runtime permission prompts and the app-settings shortcut
  /// (`permission_handler`).
  static bool get hasPermissionHandler => isMobile;

  /// Local notifications are set up for this platform. Windows and Linux
  /// need their own initialization settings before they can be enabled.
  static bool get hasLocalNotifications =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Height of the macOS title bar that the app draws underneath. The window
  /// has a transparent title bar (see `MainFlutterWindow.swift`), so content
  /// must leave this much room at the top for the traffic-light buttons and
  /// for dragging the window. Zero elsewhere.
  static double get titleBarInset => Platform.isMacOS ? 28 : 0;
}
