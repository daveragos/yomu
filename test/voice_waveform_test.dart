import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/utils/voice_waveform.dart';

void main() {
  test('microphone readings map to 0 (silent) through 1 (loudest)', () {
    expect(VoiceWaveform.level(-160), 0);
    expect(VoiceWaveform.level(double.nan), 0);
    expect(VoiceWaveform.level(-25), closeTo(0.5, 0.001));
    expect(VoiceWaveform.level(0), 1);
    expect(VoiceWaveform.level(3), 1);
  });

  test('a recording is saved as 64 bars scaled to its loudest moment', () {
    final levels = [for (var i = 0; i < 400; i++) i == 200 ? 0.6 : 0.1];
    final bars = VoiceWaveform.decode(VoiceWaveform.fromLevels(levels))!;
    expect(bars, hasLength(VoiceWaveform.barCount));
    expect(bars.reduce((a, b) => a > b ? a : b), 1);
    expect(bars.where((b) => b == 1), hasLength(1));
    expect(bars.first, closeTo(0.1 / 0.6, 0.01));
  });

  test('short recordings are stretched across all bars', () {
    final bars = VoiceWaveform.decode(VoiceWaveform.fromLevels([0.2, 0.8]))!;
    expect(bars, hasLength(VoiceWaveform.barCount));
    expect(bars.first, closeTo(0.25, 0.01));
    expect(bars.last, 1);
  });

  test('silence and missing data', () {
    expect(VoiceWaveform.fromLevels([]), isNull);
    expect(
      VoiceWaveform.decode(VoiceWaveform.fromLevels([0, 0, 0])),
      everyElement(0),
    );
    expect(VoiceWaveform.decode(null), isNull);
    expect(VoiceWaveform.decode('not base64!'), isNull);
  });

  test('resampling keeps short peaks', () {
    final values = List<double>.filled(100, 0)..[37] = 1;
    final squeezed = VoiceWaveform.resample(values, 10);
    expect(squeezed, hasLength(10));
    expect(squeezed[3], 1);
    expect(VoiceWaveform.resample([0.5], 4), [0.5, 0.5, 0.5, 0.5]);
  });
}
