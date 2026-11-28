import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/yomu_colors.dart';
import '../../../services/annotation_audio_service.dart';
import '../../../services/voice_note_playback.dart';
import '../../../utils/voice_waveform.dart';

String formatVoiceNoteDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Play/pause control and waveform for a voice note attached to an annotation.
/// Tap or drag along the waveform to jump to a point.
///
/// All players share [VoiceNotePlayback], so starting one note stops another
/// and pauses the audiobook.
class VoiceNotePlayer extends StatefulWidget {
  final String fileName;
  final int? durationMs;

  /// Saved waveform ([VoiceWaveform]); notes without one show even bars.
  final String? waveform;

  /// Defaults to the theme's accent.
  final Color? color;
  final Color? trackColor;
  final bool dense;

  /// Grows the bars in when first shown, e.g. right after recording.
  final bool animateIn;

  const VoiceNotePlayer({
    super.key,
    required this.fileName,
    this.durationMs,
    this.waveform,
    this.color,
    this.trackColor,
    this.dense = false,
    this.animateIn = false,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final VoiceNotePlayback _playback = VoiceNotePlayback.instance;
  bool _missing = false;

  /// Where the reader is dragging along the waveform, 0 to 1.
  double? _dragProgress;

  late List<double> _bars = _decodeBars();

  List<double> _decodeBars() =>
      VoiceWaveform.decode(widget.waveform) ??
      List.filled(VoiceWaveform.barCount, 0);

  bool get _isCurrent => _playback.isCurrent(widget.fileName);

  @override
  void initState() {
    super.initState();
    _checkFile();
  }

  @override
  void didUpdateWidget(VoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waveform != widget.waveform) _bars = _decodeBars();
    if (oldWidget.fileName != widget.fileName) {
      _missing = false;
      _checkFile();
    }
  }

  Future<void> _checkFile() async {
    final path = await AnnotationAudioService.resolve(widget.fileName);
    final exists = await File(path).exists();
    if (!exists && mounted) setState(() => _missing = true);
  }

  Duration get _total {
    final fallback = Duration(milliseconds: widget.durationMs ?? 0);
    return _isCurrent ? (_playback.duration ?? fallback) : fallback;
  }

  Future<void> _toggle() async {
    if (_playback.isPlaying(widget.fileName)) {
      await _playback.pause();
      return;
    }
    if (!await _playback.play(widget.fileName) && mounted) {
      setState(() => _missing = true);
    }
  }

  Future<void> _seekTo(double progress) async {
    final target = _total * progress.clamp(0.0, 1.0);
    if (_isCurrent) {
      await _playback.seek(target);
    } else if (!await _playback.play(widget.fileName, from: target) &&
        mounted) {
      setState(() => _missing = true);
    }
  }

  double _progressAt(Offset position, double width) =>
      width <= 0 ? 0 : (position.dx / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.dense ? 18.0 : 22.0;
    final buttonSize = widget.dense ? 30.0 : 38.0;
    final colors = context.yomu;
    final color = widget.color ?? colors.accent;

    if (_missing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off_rounded, size: iconSize, color: colors.tint(0.38)),
          const SizedBox(width: 6),
          Text(
            'Voice note unavailable',
            style: TextStyle(color: colors.tint(0.38), fontSize: 12),
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: _playback,
      builder: (context, _) {
        final isCurrent = _isCurrent;
        final playing = _playback.isPlaying(widget.fileName);
        return Row(
          children: [
            SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: IconButton(
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: color,
                  size: iconSize,
                ),
                tooltip: playing ? 'Pause voice note' : 'Play voice note',
                onPressed: _toggle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<Duration>(
                stream: isCurrent ? _playback.positionStream : null,
                builder: (context, snapshot) {
                  final total = _total;
                  final position = isCurrent
                      ? (snapshot.data ?? Duration.zero)
                      : Duration.zero;
                  final played = total.inMilliseconds > 0
                      ? (position.inMilliseconds / total.inMilliseconds).clamp(
                          0.0,
                          1.0,
                        )
                      : 0.0;
                  final shown = _dragProgress ?? played;
                  final shownTime = _dragProgress != null
                      ? total * shown
                      : position;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildWaveform(shown, total, shownTime, color),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        playing ||
                                position > Duration.zero ||
                                _dragProgress != null
                            ? formatVoiceNoteDuration(shownTime)
                            : formatVoiceNoteDuration(total),
                        style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: widget.dense ? 11 : 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        _SpeedChip(
                          speed: _playback.speed,
                          color: color,
                          dense: widget.dense,
                          onTap: _playback.cycleSpeed,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static Duration _clampTime(Duration time, Duration total) =>
      time < Duration.zero ? Duration.zero : (time > total ? total : time);

  Widget _buildWaveform(
    double shown,
    Duration total,
    Duration shownTime,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final step = total.inMilliseconds > 0
            ? 5000 / total.inMilliseconds
            : 0.1;
        return Semantics(
          slider: true,
          label: 'Voice note position',
          value:
              '${formatVoiceNoteDuration(shownTime)} of '
              '${formatVoiceNoteDuration(total)}',
          // A slider that can step must say what it steps to.
          increasedValue:
              '${formatVoiceNoteDuration(_clampTime(shownTime + const Duration(seconds: 5), total))} of '
              '${formatVoiceNoteDuration(total)}',
          decreasedValue:
              '${formatVoiceNoteDuration(_clampTime(shownTime - const Duration(seconds: 5), total))} of '
              '${formatVoiceNoteDuration(total)}',
          onIncrease: () => _seekTo(shown + step),
          onDecrease: () => _seekTo(shown - step),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _seekTo(_progressAt(d.localPosition, width)),
            onHorizontalDragStart: (d) => setState(
              () => _dragProgress = _progressAt(d.localPosition, width),
            ),
            onHorizontalDragUpdate: (d) => setState(
              () => _dragProgress = _progressAt(d.localPosition, width),
            ),
            onHorizontalDragEnd: (_) {
              final target = _dragProgress;
              setState(() => _dragProgress = null);
              if (target != null) _seekTo(target);
            },
            onHorizontalDragCancel: () => setState(() => _dragProgress = null),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: widget.animateIn ? 0 : 1, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (context, grow, _) => VoiceWaveformBars(
                values: _bars,
                progress: shown,
                grow: grow,
                height: widget.dense ? 22 : 28,
                playedColor: color,
                unplayedColor:
                    widget.trackColor ?? color.withValues(alpha: 0.3),
                dense: widget.dense,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.color,
    required this.dense,
    required this.onTap,
  });

  final double speed;
  final Color color;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Playback speed ${formatPlaybackSpeed(speed)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            formatPlaybackSpeed(speed),
            style: TextStyle(
              color: color,
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded loudness bars. Bars up to [progress] use [playedColor], with the
/// bar under the playhead filled part way.
///
/// By default [values] are stretched or squeezed to fill the width. With
/// [live], each value is one bar and the newest values sit at the right
/// edge, scrolling in as a recording goes. [grow] scales the bar heights,
/// for animating them in.
class VoiceWaveformBars extends StatelessWidget {
  final List<double> values;
  final double progress;
  final double height;
  final Color playedColor;
  final Color unplayedColor;
  final bool dense;
  final bool live;
  final double grow;

  const VoiceWaveformBars({
    super.key,
    required this.values,
    required this.height,
    required this.playedColor,
    required this.unplayedColor,
    this.progress = 1,
    this.dense = false,
    this.live = false,
    this.grow = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          values: values,
          valueCount: values.length,
          progress: progress,
          playedColor: playedColor,
          unplayedColor: unplayedColor,
          barWidth: dense ? 2.5 : 3,
          gap: dense ? 1.5 : 2,
          live: live,
          grow: grow,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.values,
    required this.valueCount,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.barWidth,
    required this.gap,
    required this.live,
    required this.grow,
  });

  final List<double> values;

  /// Length of [values] when painted; a live recording grows in place.
  final int valueCount;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final double barWidth;
  final double gap;
  final bool live;
  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final count = ((size.width + gap) / (barWidth + gap)).floor();
    if (count <= 0) return;

    final List<double> bars;
    if (live) {
      final recent = values.length > count
          ? values.sublist(values.length - count)
          : values;
      bars = [...List.filled(count - recent.length, 0.0), ...recent];
    } else {
      bars = VoiceWaveform.resample(values, count);
    }

    final minHeight = barWidth;
    final played = Paint()..color = playedColor;
    final unplayed = Paint()..color = unplayedColor;
    final radius = Radius.circular(barWidth / 2);
    final playhead = progress.clamp(0.0, 1.0) * count;
    for (var i = 0; i < count; i++) {
      final level = bars[i].clamp(0.0, 1.0) * grow.clamp(0.0, 1.2);
      final barHeight = (minHeight + (size.height - minHeight) * level).clamp(
        minHeight,
        size.height,
      );
      final left = i * (barWidth + gap);
      final top = (size.height - barHeight) / 2;
      final bar = RRect.fromLTRBR(
        left,
        top,
        left + barWidth,
        top + barHeight,
        radius,
      );
      final fill = (playhead - i).clamp(0.0, 1.0);
      if (fill >= 1) {
        canvas.drawRRect(bar, played);
        continue;
      }
      canvas.drawRRect(bar, unplayed);
      if (fill > 0) {
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(left, 0, left + barWidth * fill, size.height),
        );
        canvas.drawRRect(bar, played);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.valueCount != valueCount ||
      old.grow != grow ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor ||
      old.live != live;
}
