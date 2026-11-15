import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import '../../../core/yomu_colors.dart';
import '../../../services/annotation_audio_service.dart';
import '../../../services/voice_note_playback.dart';
import '../../../utils/voice_waveform.dart';
import 'voice_note_player.dart';

/// Records, previews and removes the voice note of an annotation.
///
/// Hold the mic to record, the way chat apps work: let go to keep the
/// recording, slide left to throw it away, slide up to lock it and keep
/// talking hands-free (then STOP to keep it). Recordings have no length limit.
///
/// Files are written straight into the annotation audio folder. The owner
/// ([NoteEditor]) decides which files to keep when the note is saved or
/// dismissed, using [onRecorded] and [onRemoved].
class VoiceNoteRecorder extends StatefulWidget {
  final String? fileName;
  final int? durationMs;
  final String? waveform;
  final void Function(String fileName, int durationMs, String? waveform)
  onRecorded;
  final VoidCallback onRemoved;

  /// Prompt shown before anything is recorded.
  final String prompt;

  /// How often the microphone level is read, i.e. one live bar per reading.
  static const Duration levelInterval = Duration(milliseconds: 80);

  const VoiceNoteRecorder({
    super.key,
    required this.fileName,
    required this.durationMs,
    required this.waveform,
    required this.onRecorded,
    required this.onRemoved,
    this.prompt = 'Add a voice note',
  });

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

enum _Mode { idle, holding, locked }

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  static const _cancelDistance = 110.0;
  static const _lockDistance = 70.0;

  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  StreamSubscription<Amplitude>? _levelSub;
  String? _recordingFile;
  bool _starting = false;
  _Mode _mode = _Mode.idle;

  /// Whether the finger is still down on the mic in hold mode.
  bool _pressing = false;
  Offset _drag = Offset.zero;

  /// The file that was just recorded, so its bars animate in once.
  String? _justRecorded;

  /// Microphone loudness so far, 0 to 1, one per [VoiceNoteRecorder.levelInterval].
  final List<double> _levels = [];

  bool get _isRecording => _recordingFile != null;

  @override
  void dispose() {
    _messageTimer?.cancel();
    _ticker?.cancel();
    _levelSub?.cancel();
    if (_isRecording) {
      // Discards the partial file; the editor cleans up anything else.
      _recorder.cancel();
    }
    _recorder.dispose();
    super.dispose();
  }

  /// A short message shown inside the recorder. Snack bars would sit
  /// behind the note sheets this recorder lives in.
  String? _message;
  Timer? _messageTimer;

  void _snack(String message) {
    if (!mounted) return;
    _messageTimer?.cancel();
    setState(() => _message = message);
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  /// A tap on the mic only explains how recording works.
  void _hint() {
    HapticFeedback.selectionClick();
    _snack('Hold the mic to record. Slide up to lock, left to cancel.');
  }

  Future<void> _start() async {
    if (_starting || _isRecording) return;
    _starting = true;
    _pressing = true;
    _drag = Offset.zero;
    try {
      if (!await _recorder.hasPermission()) {
        _snack('Microphone access is needed to record a note.');
        return;
      }
      // The permission prompt can swallow the press: don't record a note
      // nobody is holding down.
      if (!_pressing) {
        _snack('Microphone ready. Hold the mic to record.');
        return;
      }
      await VoiceNotePlayback.instance.pause();
      final fileName = AnnotationAudioService.newFileName();
      final path = await AnnotationAudioService.resolve(fileName);
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      HapticFeedback.mediumImpact();
      _levels.clear();
      _levelSub = _recorder
          .onAmplitudeChanged(VoiceNoteRecorder.levelInterval)
          .listen((amplitude) {
            _levels.add(VoiceWaveform.level(amplitude.current));
            if (mounted) setState(() {});
          });
      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() {
          _recordingFile = fileName;
          _mode = _Mode.holding;
        });
      }
      // Let go while the recorder was still starting.
      if (!_pressing) await _stop();
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      _snack('Could not start recording.');
    } finally {
      _starting = false;
    }
  }

  Future<void> _finishRecorder() async {
    _ticker?.cancel();
    await _levelSub?.cancel();
    _levelSub = null;
    _stopwatch.stop();
  }

  Future<void> _stop() async {
    final fileName = _recordingFile;
    if (fileName == null) return;
    await _finishRecorder();
    final elapsed = _stopwatch.elapsed;
    if (mounted) {
      setState(() {
        _recordingFile = null;
        _mode = _Mode.idle;
      });
    }

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
    }

    if (elapsed < const Duration(milliseconds: 600)) {
      await AnnotationAudioService.delete(fileName);
      _snack('Too short. Keep holding the mic while you talk.');
      return;
    }
    HapticFeedback.lightImpact();
    _justRecorded = fileName;
    widget.onRecorded(
      fileName,
      elapsed.inMilliseconds,
      VoiceWaveform.fromLevels(_levels),
    );
  }

  Future<void> _cancel() async {
    final fileName = _recordingFile;
    if (fileName == null) return;
    await _finishRecorder();
    if (mounted) {
      setState(() {
        _recordingFile = null;
        _mode = _Mode.idle;
        _drag = Offset.zero;
      });
    }
    try {
      await _recorder.cancel();
    } catch (e) {
      debugPrint('Failed to cancel recording: $e');
    }
    await AnnotationAudioService.delete(fileName);
    HapticFeedback.heavyImpact();
  }

  void _onHoldMove(LongPressMoveUpdateDetails details) {
    if (_mode != _Mode.holding) return;
    final offset = details.offsetFromOrigin;
    if (offset.dx <= -_cancelDistance) {
      _cancel();
      return;
    }
    if (offset.dy <= -_lockDistance) {
      HapticFeedback.selectionClick();
      setState(() {
        _mode = _Mode.locked;
        _drag = Offset.zero;
      });
      return;
    }
    setState(() {
      _drag = Offset(
        offset.dx.clamp(-_cancelDistance, 0),
        offset.dy.clamp(-_lockDistance, 0),
      );
    });
  }

  void _onHoldEnd() {
    _pressing = false;
    if (_mode == _Mode.holding) _stop();
  }

  /// The mic of a recorded note, which can be held to record again.
  final GlobalKey _micKey = GlobalKey();

  /// Whether a press at [global] is on the mic: the whole row before
  /// anything is recorded, the mic button after.
  bool _onMic(Offset global) {
    // While a hint is up, the whole frame stands in for the mic.
    if (widget.fileName == null || _message != null) return true;
    final box = _micKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return rect.inflate(6).contains(global);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.yomu;
    final Widget content;

    if (_isRecording) {
      content = _buildRecording();
    } else if (_message != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.touch_app_outlined,
              color: colors.accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _message!,
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (widget.fileName != null) {
      content = Row(
        children: [
          Expanded(
            child: VoiceNotePlayer(
              key: ValueKey(widget.fileName),
              fileName: widget.fileName!,
              durationMs: widget.durationMs,
              waveform: widget.waveform,
              animateIn: widget.fileName == _justRecorded,
            ),
          ),
          Semantics(
            button: true,
            label: 'Record again',
            child: InkWell(
              key: _micKey,
              customBorder: const CircleBorder(),
              onTap: _hint,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.mic_rounded, color: colors.tint(0.54)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.tint(0.38)),
            tooltip: 'Remove voice note',
            onPressed: widget.onRemoved,
          ),
        ],
      );
    } else {
      content = Semantics(
        button: true,
        label: '${widget.prompt}. Hold to record.',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.mic_none_rounded, color: colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.prompt,
                  style: TextStyle(color: colors.tint(0.70), fontSize: 14),
                ),
              ),
              Text(
                'Hold to record',
                style: TextStyle(color: colors.tint(0.30), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    // One detector for the whole frame, so a hold that starts on the mic
    // keeps being tracked after the frame switches to the recording view.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.fileName == null && !_isRecording ? _hint : null,
      onLongPressStart: (details) {
        if (!_isRecording && _onMic(details.globalPosition)) _start();
      },
      onLongPressMoveUpdate: _onHoldMove,
      onLongPressEnd: (_) => _onHoldEnd(),
      onLongPressCancel: _onHoldEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colors.tint(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRecording
                ? Colors.redAccent.withValues(alpha: 0.5)
                : colors.tint(0.10),
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildRecording() {
    final colors = context.yomu;
    final holding = _mode == _Mode.holding;
    final cancelProgress = (-_drag.dx / _cancelDistance).clamp(0.0, 1.0);
    final lockProgress = (-_drag.dy / _lockDistance).clamp(0.0, 1.0);

    final row = Row(
      children: [
        const _PulsingDot(),
        const SizedBox(width: 10),
        Text(
          formatVoiceNoteDuration(_stopwatch.elapsed),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Opacity(
            opacity: 1 - cancelProgress * 0.7,
            child: VoiceWaveformBars(
              values: _levels,
              height: 28,
              live: true,
              playedColor: colors.accent,
              unplayedColor: colors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (holding)
          Opacity(
            opacity: 1 - cancelProgress,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: colors.tint(0.54),
                ),
                Text(
                  'Cancel',
                  style: TextStyle(color: colors.tint(0.54), fontSize: 12),
                ),
                const SizedBox(width: 10),
                Transform.translate(
                  offset: Offset(0, -6 * lockProgress),
                  child: Icon(
                    lockProgress > 0.5
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    size: 18,
                    color: Color.lerp(
                      colors.tint(0.38),
                      colors.accent,
                      lockProgress,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, color: colors.tint(0.38)),
            tooltip: 'Discard recording',
            onPressed: _cancel,
          ),
          TextButton.icon(
            onPressed: _stop,
            icon: const Icon(Icons.stop_rounded, color: Colors.redAccent),
            label: const Text(
              'STOP',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );

    return Transform.translate(
      offset: Offset(holding ? _drag.dx * 0.4 : 0, 0),
      child: row,
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
