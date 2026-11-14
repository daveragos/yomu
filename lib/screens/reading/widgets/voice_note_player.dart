import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/constants.dart';
import '../../../services/annotation_audio_service.dart';

String formatVoiceNoteDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Compact play/pause control for a voice note attached to an annotation.
class VoiceNotePlayer extends StatefulWidget {
  final String fileName;
  final int? durationMs;
  final Color color;
  final Color? trackColor;
  final bool dense;

  const VoiceNotePlayer({
    super.key,
    required this.fileName,
    this.durationMs,
    this.color = YomuConstants.accent,
    this.trackColor,
    this.dense = false,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  bool _loaded = false;
  bool _missing = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
      final playing =
          state.playing && state.processingState != ProcessingState.completed;
      if (mounted && playing != _playing) {
        setState(() => _playing = playing);
      }
    });
  }

  @override
  void didUpdateWidget(VoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileName != widget.fileName) {
      _player.stop();
      _loaded = false;
      _missing = false;
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (!_loaded) {
      final path = await AnnotationAudioService.resolve(widget.fileName);
      if (!await File(path).exists()) {
        if (mounted) setState(() => _missing = true);
        return;
      }
      try {
        await _player.setFilePath(path);
        _loaded = true;
      } catch (e) {
        debugPrint('Failed to load voice note: $e');
        if (mounted) setState(() => _missing = true);
        return;
      }
    }
    _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.dense ? 18.0 : 22.0;
    final buttonSize = widget.dense ? 30.0 : 38.0;
    final fallback = Duration(milliseconds: widget.durationMs ?? 0);

    if (_missing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off_rounded, size: iconSize, color: Colors.white38),
          const SizedBox(width: 6),
          const Text(
            'Voice note unavailable',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: IconButton(
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: widget.color.withValues(alpha: 0.15),
            ),
            icon: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.color,
              size: iconSize,
            ),
            tooltip: _playing ? 'Pause voice note' : 'Play voice note',
            onPressed: _toggle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final total = _player.duration ?? fallback;
              final position = snapshot.data ?? Duration.zero;
              final value = total.inMilliseconds > 0
                  ? (position.inMilliseconds / total.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    )
                  : 0.0;
              return Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 3,
                        color: widget.color,
                        backgroundColor:
                            widget.trackColor ??
                            widget.color.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _playing || position > Duration.zero
                        ? formatVoiceNoteDuration(position)
                        : formatVoiceNoteDuration(total),
                    style: TextStyle(
                      color: widget.color.withValues(alpha: 0.8),
                      fontSize: widget.dense ? 11 : 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
