import 'dart:io';

import 'package:flutter/services.dart';

/// The iPhone's built-in dictionary sheet, the one behind "Look Up" (see
/// `ios/Runner/DictionaryPlugin.swift`).
abstract final class SystemDictionary {
  static const _channel = MethodChannel('yomu/dictionary');

  /// Shows [word] in the dictionary sheet. Returns false where there is no
  /// such sheet, so the caller can fall back to something else.
  static Future<bool> show(String word) async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('show', word) ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
