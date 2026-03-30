import 'package:flutter/material.dart';
import '../../../models/reader_settings_model.dart';
import '../../../models/book_model.dart';
import '../../../core/constants.dart';

class ReadingAudioSection extends StatelessWidget {
  final ReaderSettings settings;
  final bool isLoading;
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration> durationNotifier;
  final ValueNotifier<int> currentIndexNotifier;
  final List<AudioTrack> audioTracks;
  final bool isDraggingSlider;
  final double sliderDragValue;
  final Function(double) onChangeStart;
  final Function(double) onChanged;
  final Function(double) onChangeEnd;
  final String Function(Duration) formatDuration;
  final bool isOrientationLandscape;

  const ReadingAudioSection({
    super.key,
    required this.settings,
    required this.isLoading,
    required this.positionNotifier,
    required this.durationNotifier,
    required this.currentIndexNotifier,
    required this.audioTracks,
    required this.isDraggingSlider,
    required this.sliderDragValue,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.formatDuration,
    this.isOrientationLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: isOrientationLandscape ? 8 : 20,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final slider = ValueListenableBuilder<Duration>(
      valueListenable: positionNotifier,
      builder: (context, pos, _) => ValueListenableBuilder<Duration>(
        valueListenable: durationNotifier,
        builder: (context, dur, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: YomuConstants.accent,
              inactiveTrackColor: settings.textColor.withValues(alpha: 0.1),
              thumbColor: YomuConstants.accent,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: isOrientationLandscape ? 4 : 6,
              ),
              trackHeight: isOrientationLandscape ? 2 : 3,
              overlayShape: RoundSliderOverlayShape(
                overlayRadius: isOrientationLandscape ? 12 : 20,
              ),
            ),
            child: Slider(
              value: isDraggingSlider
                  ? sliderDragValue.clamp(0, dur.inMilliseconds.toDouble())
                  : pos.inMilliseconds.toDouble().clamp(
                      0,
                      dur.inMilliseconds.toDouble(),
                    ),
              max: dur.inMilliseconds.toDouble().clamp(1, double.infinity),
              onChangeStart: onChangeStart,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
      ),
    );

    if (isOrientationLandscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(
          children: [
            if (audioTracks.length > 1)
              ValueListenableBuilder<int>(
                valueListenable: currentIndexNotifier,
                builder: (context, index, _) {
                  return Text(
                    'P${index + 1}/${audioTracks.length}',
                    style: TextStyle(
                      color: settings.secondaryTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            const SizedBox(width: 8),
            ValueListenableBuilder<Duration>(
              valueListenable: positionNotifier,
              builder: (context, pos, _) => Text(
                formatDuration(pos),
                style: TextStyle(
                  color: settings.secondaryTextColor,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(child: slider),
            ValueListenableBuilder<Duration>(
              valueListenable: durationNotifier,
              builder: (context, dur, _) => Text(
                formatDuration(dur),
                style: TextStyle(
                  color: settings.secondaryTextColor,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          if (audioTracks.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ValueListenableBuilder<int>(
                valueListenable: currentIndexNotifier,
                builder: (context, index, _) {
                  final track = index < audioTracks.length
                      ? audioTracks[index]
                      : null;
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          track?.title ?? 'Unknown Part',
                          style: TextStyle(
                            color: settings.textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Part ${index + 1} of ${audioTracks.length}',
                        style: TextStyle(
                          color: settings.secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: 45,
                child: ValueListenableBuilder<Duration>(
                  valueListenable: positionNotifier,
                  builder: (context, pos, _) => Text(
                    formatDuration(pos),
                    style: TextStyle(
                      color: settings.secondaryTextColor,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(child: slider),
              SizedBox(
                width: 45,
                child: ValueListenableBuilder<Duration>(
                  valueListenable: durationNotifier,
                  builder: (context, dur, _) => Text(
                    formatDuration(dur),
                    style: TextStyle(
                      color: settings.secondaryTextColor,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
