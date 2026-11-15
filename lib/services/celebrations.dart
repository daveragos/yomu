import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a celebration is about; picks the toast's icon.
enum CelebrationKind { achievement, quest, level, rank }

/// One gamified moment: an achievement, a finished quest, a new level or a
/// new rank.
@immutable
class Celebration {
  final CelebrationKind kind;
  final String title;
  final String body;

  /// Identifies the event itself. The level listener and the quest check can
  /// both see the same rank-up, so a second celebration with a key already
  /// shown in the last minute is dropped.
  final String key;

  const Celebration({
    required this.kind,
    required this.title,
    required this.body,
    required this.key,
  });
}

/// Desktop celebration toasts. Code that notices an achievement, quest,
/// level or rank calls [show].
///
/// On macOS the card is a native panel at the top right of the screen
/// (`macos/Runner/CelebrationPanel.swift`), so it shows over other apps even
/// when Yomu is in the background. Elsewhere, or if that panel isn't
/// available, `CelebrationToastHost` draws it inside the window from
/// [stream].
abstract final class Celebrations {
  static const _panel = MethodChannel('yomu/celebrations');
  static final _controller = StreamController<Celebration>.broadcast();
  static final Map<String, DateTime> _recent = {};
  static const _dedupeWindow = Duration(minutes: 1);

  static Stream<Celebration> get stream => _controller.stream;

  static void show(Celebration celebration) {
    final now = DateTime.now();
    _recent.removeWhere((_, at) => now.difference(at) > _dedupeWindow);
    if (_recent.containsKey(celebration.key)) return;
    _recent[celebration.key] = now;

    if (Platform.isMacOS) {
      _panel
          .invokeMethod<void>('show', {
            'kind': celebration.kind.name,
            'title': celebration.title,
            'body': celebration.body,
          })
          .catchError((Object _) => _controller.add(celebration));
      return;
    }
    _controller.add(celebration);
  }
}
