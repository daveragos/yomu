import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'annotation_audio_service.dart';

/// Plays voice notes one at a time for the whole app, so two notes (or a note
/// and the audiobook) never talk over each other.
///
/// Every voice note player shows this shared state. The reading screen
/// listens to [onStart] and [onFinish] to pause the audiobook while a note
/// plays and resume it afterwards.
class VoiceNotePlayback extends ChangeNotifier {
  VoiceNotePlayback._();
  static final VoiceNotePlayback instance = VoiceNotePlayback._();

  static const speeds = [1.0, 1.5, 2.0];
  static const _speedKey = 'voice_note_speed';

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  String? _current;
  bool _playing = false;
  double _speed = 1.0;
  bool _speedLoaded = false;

  /// Called right before a voice note starts playing.
  final List<VoidCallback> onStart = [];

  /// Called when a voice note plays to its end.
  final List<VoidCallback> onFinish = [];

  /// File name of the loaded voice note, playing or paused.
  String? get current => _current;
  bool get playing => _playing;
  double get speed => _speed;
  bool isCurrent(String fileName) => _current == fileName;
  bool isPlaying(String fileName) => _playing && _current == fileName;

  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream.empty();
  Duration? get duration => _player?.duration;

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _stateSub = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        player.pause();
        player.seek(Duration.zero);
        _setPlaying(false);
        for (final listener in List.of(onFinish)) {
          listener();
        }
        return;
      }
      _setPlaying(state.playing);
    });
    return _player = player;
  }

  void _setPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    notifyListeners();
  }

  Future<void> _loadSpeed() async {
    if (_speedLoaded) return;
    _speedLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_speedKey);
      if (saved != null && speeds.contains(saved)) _speed = saved;
    } catch (_) {}
  }

  /// Loads [fileName] if it isn't loaded yet. False when the file is gone.
  Future<bool> _load(String fileName) async {
    final player = _ensurePlayer();
    if (_current == fileName) return true;
    await _loadSpeed();
    final path = await AnnotationAudioService.resolve(fileName);
    if (!await File(path).exists()) return false;
    try {
      await player.stop();
      await player.setFilePath(path);
      await player.setSpeed(_speed);
    } catch (e) {
      debugPrint('Failed to load voice note: $e');
      return false;
    }
    _current = fileName;
    _playing = false;
    notifyListeners();
    return true;
  }

  /// Plays [fileName], from [from] when given. False when the file is gone.
  Future<bool> play(String fileName, {Duration? from}) async {
    if (!await _load(fileName)) return false;
    final player = _player!;
    if (from != null) await player.seek(from);
    for (final listener in List.of(onStart)) {
      listener();
    }
    unawaited(player.play());
    return true;
  }

  Future<void> pause() async => _player?.pause();

  /// Jumps within the loaded voice note.
  Future<void> seek(Duration position) async => _player?.seek(position);

  /// Stops and unloads the current voice note.
  Future<void> stop() async {
    await _player?.stop();
    _current = null;
    _setPlaying(false);
    notifyListeners();
  }

  /// Steps to the next speed (1×, 1.5×, 2×) and remembers it.
  Future<void> cycleSpeed() async {
    await _loadSpeed();
    final next = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    _speed = next;
    await _player?.setSpeed(next);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speedKey, next);
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> reset() async {
    await _stateSub?.cancel();
    await _player?.dispose();
    _player = null;
    _stateSub = null;
    _current = null;
    _playing = false;
  }
}

String formatPlaybackSpeed(double speed) =>
    speed == speed.roundToDouble() ? '${speed.toInt()}×' : '$speed×';
