import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

/// Records voice notes.
///
/// On Android this is Yomu's own recorder (VoiceNoteCapture.kt), which
/// cleans the sound as it records, the way chat apps do: it takes out the
/// rumble phone microphones pick up under the voice and keeps speech at a
/// steady level, so the note is finished the moment recording stops.
/// Elsewhere the record plugin is used.
abstract class VoiceCapture {
  factory VoiceCapture() => !kIsWeb && Platform.isAndroid
      ? _AndroidVoiceCapture()
      : _PluginVoiceCapture();

  /// Asks for the microphone if needed.
  Future<bool> hasPermission();

  /// Starts recording an AAC file at [path].
  Future<void> start(String path);

  /// Loudness every [interval], in dBFS, while recording.
  Stream<double> levels(Duration interval);

  Future<void> stop();

  /// Stops and deletes the file.
  Future<void> cancel();

  Future<void> dispose();
}

class _AndroidVoiceCapture implements VoiceCapture {
  static const _channel = MethodChannel('com.ragoose.yomu/voice_note');

  /// Only used to ask for the microphone.
  final _permission = AudioRecorder();

  @override
  Future<bool> hasPermission() => _permission.hasPermission();

  @override
  Future<void> start(String path) =>
      _channel.invokeMethod<void>('start', {'path': path});

  @override
  Stream<double> levels(Duration interval) =>
      Stream.periodic(interval).asyncMap(
        (_) async => (await _channel.invokeMethod<double>('level')) ?? -160,
      );

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');

  @override
  Future<void> dispose() => _permission.dispose();
}

class _PluginVoiceCapture implements VoiceCapture {
  final _recorder = AudioRecorder();

  /// The phone's own microphone (a Bluetooth headset would switch to
  /// narrow-band call audio), automatic gain and noise suppression, AAC at
  /// 48 kHz, 96 kbps.
  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 96000,
    sampleRate: 48000,
    numChannels: 1,
    autoGain: true,
    noiseSuppress: true,
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.mic,
      manageBluetooth: false,
    ),
  );

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(_config, path: path);

  @override
  Stream<double> levels(Duration interval) =>
      _recorder.onAmplitudeChanged(interval).map((a) => a.current);

  @override
  Future<void> stop() async => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}
