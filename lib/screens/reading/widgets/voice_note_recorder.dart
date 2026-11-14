import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../../core/constants.dart';
import '../../../services/annotation_audio_service.dart';
import 'voice_note_player.dart';

/// Records, previews and removes the voice note of an annotation.
///
/// Files are written straight into the annotation audio folder. The owner
/// ([NoteEditor]) decides which files to keep when the note is saved or
/// dismissed, using [onRecorded] and [onRemoved].
class VoiceNoteRecorder extends StatefulWidget {
  final String? fileName;
  final int? durationMs;
  final void Function(String fileName, int durationMs) onRecorded;
  final VoidCallback onRemoved;

  static const Duration maxDuration = Duration(minutes: 5);

  const VoiceNoteRecorder({
    super.key,
    required this.fileName,
    required this.durationMs,
    required this.onRecorded,
    required this.onRemoved,
  });

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  String? _recordingFile;
  bool _starting = false;

  bool get _isRecording => _recordingFile != null;

  @override
  void dispose() {
    _ticker?.cancel();
    if (_isRecording) {
      // Discards the partial file; the editor cleans up anything else.
      _recorder.cancel();
    }
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _isRecording) return;
    _starting = true;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone access is needed to record a note.'),
            ),
          );
        }
        return;
      }
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
      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_stopwatch.elapsed >= VoiceNoteRecorder.maxDuration) {
          _stop();
        } else if (mounted) {
          setState(() {});
        }
      });
      if (mounted) setState(() => _recordingFile = fileName);
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start recording.')),
        );
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    final fileName = _recordingFile;
    if (fileName == null) return;
    _ticker?.cancel();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed;
    setState(() => _recordingFile = null);

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
    }

    if (elapsed < const Duration(milliseconds: 600)) {
      await AnnotationAudioService.delete(fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording was too short.')),
        );
      }
      return;
    }
    widget.onRecorded(fileName, elapsed.inMilliseconds);
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (_isRecording) {
      content = Row(
        children: [
          const _PulsingDot(),
          const SizedBox(width: 12),
          Text(
            'Recording  ${formatVoiceNoteDuration(_stopwatch.elapsed)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
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
      );
    } else if (widget.fileName != null) {
      content = Row(
        children: [
          Expanded(
            child: VoiceNotePlayer(
              key: ValueKey(widget.fileName),
              fileName: widget.fileName!,
              durationMs: widget.durationMs,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: Colors.white54),
            tooltip: 'Record again',
            onPressed: _start,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
            tooltip: 'Remove voice note',
            onPressed: widget.onRemoved,
          ),
        ],
      );
    } else {
      content = InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _start,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.mic_none_rounded, color: YomuConstants.accent),
              SizedBox(width: 12),
              Text(
                'Add a voice note',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRecording
              ? Colors.redAccent.withValues(alpha: 0.5)
              : Colors.white10,
        ),
      ),
      child: content,
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
