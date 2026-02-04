import 'package:flutter/material.dart';
import '../../../models/reader_settings_model.dart';
import '../../../core/constants.dart';

class ReadingAudioSection extends StatelessWidget {
  final ReaderSettings settings;
  final bool isLoading;
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration> durationNotifier;
  final bool isDraggingSlider;
  final double sliderDragValue;
  final Function(double) onChangeStart;
  final Function(double) onChanged;
  final Function(double) onChangeEnd;
  final String Function(Duration) formatDuration;

  const ReadingAudioSection({
    super.key,
    required this.settings,
    required this.isLoading,
    required this.positionNotifier,
    required this.durationNotifier,
    required this.isDraggingSlider,
    required this.sliderDragValue,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
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
          Expanded(
            child: ValueListenableBuilder<Duration>(
              valueListenable: positionNotifier,
              builder: (context, pos, _) => ValueListenableBuilder<Duration>(
                valueListenable: durationNotifier,
                builder: (context, dur, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: YomuConstants.accent,
                      inactiveTrackColor: settings.textColor.withValues(
                        alpha: 0.1,
                      ),
                      thumbColor: YomuConstants.accent,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: isDraggingSlider
                          ? sliderDragValue.clamp(
                              0,
                              dur.inMilliseconds.toDouble(),
                            )
                          : pos.inMilliseconds.toDouble().clamp(
                              0,
                              dur.inMilliseconds.toDouble(),
                            ),
                      max: dur.inMilliseconds.toDouble().clamp(
                        1,
                        double.infinity,
                      ),
                      onChangeStart: onChangeStart,
                      onChanged: onChanged,
                      onChangeEnd: onChangeEnd,
                    ),
                  ),
                ),
              ),
            ),
          ),
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
    );
  }
}
