import 'package:flutter/services.dart';

import '../core/platform_caps.dart';

/// Books macOS hands to Yomu: Finder's Open With, double-clicking a file
/// Yomu is set to open, or dropping files on the Dock icon. The desktop
/// counterpart of the phone's share sheet.
///
/// iOS answers the same channel for "Open in Yomu" from other apps (see
/// `ios/Runner/OpenFilesPlugin.swift`).
abstract final class DesktopOpenFiles {
  static const _channel = MethodChannel('yomu/open_files');

  /// Calls [onFiles] with the paths of each batch of files, starting with
  /// any that arrived while the app was launching. The library copies each
  /// book into its own storage as it imports it (see `LibraryFiles`).
  static Future<void> listen(void Function(List<String> paths) onFiles) async {
    if (!PlatformCaps.hasOpenFilesChannel) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') {
        onFiles(List<String>.from(call.arguments as List));
      }
    });

    try {
      final pending = await _channel.invokeListMethod<String>('takePending');
      if (pending != null && pending.isNotEmpty) onFiles(pending);
    } on MissingPluginException {
      // A build without the native side; opening from Finder just won't work.
    }
  }
}
