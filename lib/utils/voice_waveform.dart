import 'dart:convert';
import 'dart:math' as math;

/// A voice note's loudness over time, drawn as bars the way chat apps do.
///
/// Saved with the note as [barCount] values from 0 to 255, base64-encoded,
/// and scaled so the loudest bar is full height.
class VoiceWaveform {
  static const barCount = 64;

  /// Readings at or below this many dBFS count as silence.
  static const double _floorDb = -50;

  /// Loudness of one microphone reading in dBFS, from 0 (silent) to 1.
  static double level(double dbfs) {
    if (dbfs.isNaN || dbfs <= _floorDb) return 0;
    if (dbfs >= 0) return 1;
    return 1 - dbfs / _floorDb;
  }

  /// Squeezes or stretches [values] into [count] values, keeping the peak of
  /// each stretch so short loud sounds stay visible.
  static List<double> resample(List<double> values, int count) {
    if (values.isEmpty || count <= 0) return List.filled(math.max(count, 0), 0);
    return [
      for (var i = 0; i < count; i++)
        _peak(
          values,
          (i * values.length / count).floor(),
          math.max(
            (i * values.length / count).floor() + 1,
            ((i + 1) * values.length / count).floor(),
          ),
        ),
    ];
  }

  static double _peak(List<double> values, int start, int end) {
    var peak = 0.0;
    for (var i = start; i < end && i < values.length; i++) {
      peak = math.max(peak, values[i]);
    }
    return peak;
  }

  /// The saved form of a recording's [levels] (one per reading, 0 to 1).
  static String? fromLevels(List<double> levels) {
    if (levels.isEmpty) return null;
    final bars = resample(levels, barCount);
    final top = bars.reduce(math.max);
    return base64Encode([
      for (final bar in bars) top <= 0 ? 0 : (bar / top * 255).round(),
    ]);
  }

  /// Bar heights from 0 to 1, or null when [data] is missing or invalid.
  static List<double>? decode(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      final bytes = base64Decode(data);
      if (bytes.isEmpty || bytes.length > 256) return null;
      return [for (final b in bytes) b / 255];
    } on FormatException {
      return null;
    }
  }
}
