import 'package:flutter/material.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../core/constants.dart';
import './control_button.dart';

class ReadingBottomControls extends StatelessWidget {
  final Book book;
  final ReaderSettings settings;
  final bool isAudioControlsExpanded;
  final bool isNavigationSheetOpen;
  final bool isAutoScrolling;
  final bool isBookmarked;
  final double playbackSpeed;
  final bool isOrientationLandscape;
  final Widget? audioSection;
  final Widget playPauseButton;
  final VoidCallback onToggleAudioControls;
  final VoidCallback onPickAudio;
  final VoidCallback onShowNavigationSheet;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleAutoScroll;
  final VoidCallback onToggleOrientation;
  final VoidCallback onShowDisplaySettings;
  final VoidCallback onIncrementPlaybackSpeed;
  final Function(Duration) onSkip;
  final VoidCallback? onNextTrack;
  final VoidCallback? onPrevTrack;
  final VoidCallback? onShowTrackList;
  final GlobalKey? audioKey;
  final GlobalKey? tocKey;
  final GlobalKey? autoScrollKey;
  final GlobalKey? displaySettingsKey;

  const ReadingBottomControls({
    super.key,
    required this.book,
    required this.settings,
    required this.isAudioControlsExpanded,
    required this.isNavigationSheetOpen,
    required this.isAutoScrolling,
    required this.isBookmarked,
    required this.playbackSpeed,
    required this.isOrientationLandscape,
    required this.playPauseButton,
    required this.onToggleAudioControls,
    required this.onPickAudio,
    required this.onShowNavigationSheet,
    required this.onToggleBookmark,
    required this.onToggleAutoScroll,
    required this.onToggleOrientation,
    required this.onShowDisplaySettings,
    required this.onIncrementPlaybackSpeed,
    required this.onSkip,
    this.onNextTrack,
    this.onPrevTrack,
    this.onShowTrackList,
    this.audioKey,
    this.tocKey,
    this.autoScrollKey,
    this.displaySettingsKey,
    this.audioSection,
  });

  @override
  Widget build(BuildContext context) {
    final hasMultipleTracks = book.audioTracks.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: settings.backgroundColor,
        border: Border(
          top: BorderSide(color: settings.textColor.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((book.audioPath != null || book.audioTracks.isNotEmpty) &&
                audioSection != null)
              audioSection!
            else
              const SizedBox(height: 12),
            if (book.audioPath != null || book.audioTracks.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    SizeTransition(sizeFactor: animation, child: child),
                child: isAudioControlsExpanded
                    ? Padding(
                        padding: EdgeInsets.only(
                          bottom: isOrientationLandscape ? 8 : 16,
                        ),
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: isOrientationLandscape
                                ? const NeverScrollableScrollPhysics()
                                : const ScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isOrientationLandscape ? 40 : 16,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _buildAudioControlButtons(
                                  hasMultipleTracks,
                                  withSizedBoxes: true,
                                  spacing: isOrientationLandscape ? 32 : 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isOrientationLandscape ? 40 : 20,
                0,
                isOrientationLandscape ? 40 : 20,
                16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ControlButton(
                    key: tocKey,
                    settings: settings,
                    onTap: onShowNavigationSheet,
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      color: isNavigationSheetOpen
                          ? YomuConstants.accent
                          : settings.textColor,
                      size: 22,
                    ),
                  ),
                  ControlButton(
                    settings: settings,
                    onTap: onToggleBookmark,
                    child: Icon(
                      isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: isBookmarked
                          ? YomuConstants.accent
                          : settings.textColor,
                      size: 22,
                    ),
                  ),
                  if (book.audioPath != null || book.audioTracks.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ControlButton(
                          key: audioKey,
                          settings: settings,
                          onTap: onToggleAudioControls,
                          child: Icon(
                            isAudioControlsExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.tune_rounded,
                            color: settings.textColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        playPauseButton,
                      ],
                    )
                  else
                    ControlButton(
                      key: audioKey,
                      settings: settings,
                      onTap: onPickAudio,
                      child: const Icon(
                        Icons.add_rounded,
                        color: YomuConstants.accent,
                        size: 24,
                      ),
                    ),
                  ControlButton(
                    key: autoScrollKey,
                    settings: settings,
                    onTap: onToggleAutoScroll,
                    child: Icon(
                      isAutoScrolling
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      color: isAutoScrolling
                          ? YomuConstants.accent
                          : settings.textColor,
                      size: 22,
                    ),
                  ),
                  ControlButton(
                    settings: settings,
                    onTap: onToggleOrientation,
                    child: Icon(
                      Icons.screen_rotation_rounded,
                      color: settings.textColor,
                      size: 20,
                    ),
                  ),
                  ControlButton(
                    key: displaySettingsKey,
                    settings: settings,
                    onTap: onShowDisplaySettings,
                    child: Icon(
                      Icons.text_fields_rounded,
                      color: settings.textColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAudioControlButtons(
    bool hasMultipleTracks, {
    bool withSizedBoxes = false,
    double spacing = 20,
  }) {
    final List<Widget> buttons = [];

    buttons.add(
      ControlButton(
        settings: settings,
        onTap: onIncrementPlaybackSpeed,
        child: Text(
          '${playbackSpeed}x',
          style: TextStyle(
            color: settings.textColor,
            fontSize: isOrientationLandscape ? 12 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    if (withSizedBoxes) buttons.add(SizedBox(width: spacing));

    if (hasMultipleTracks) {
      buttons.add(
        ControlButton(
          settings: settings,
          onTap: onPrevTrack ?? () {},
          child: Icon(
            Icons.skip_previous_rounded,
            color: settings.textColor,
            size: isOrientationLandscape ? 24 : 28,
          ),
        ),
      );
      if (withSizedBoxes) buttons.add(SizedBox(width: spacing));
    }

    buttons.add(
      ControlButton(
        settings: settings,
        onTap: () => onSkip(const Duration(seconds: -10)),
        child: Icon(
          Icons.replay_10_rounded,
          color: settings.textColor,
          size: isOrientationLandscape ? 24 : 28,
        ),
      ),
    );

    if (withSizedBoxes) buttons.add(SizedBox(width: spacing));

    buttons.add(
      ControlButton(
        settings: settings,
        onTap: () => onSkip(const Duration(seconds: 10)),
        child: Icon(
          Icons.forward_10_rounded,
          color: settings.textColor,
          size: isOrientationLandscape ? 24 : 28,
        ),
      ),
    );

    if (withSizedBoxes) buttons.add(SizedBox(width: spacing));

    if (hasMultipleTracks) {
      buttons.add(
        ControlButton(
          settings: settings,
          onTap: onNextTrack ?? () {},
          child: Icon(
            Icons.skip_next_rounded,
            color: settings.textColor,
            size: isOrientationLandscape ? 24 : 28,
          ),
        ),
      );
      if (withSizedBoxes) buttons.add(SizedBox(width: spacing));

      buttons.add(
        ControlButton(
          settings: settings,
          onTap: onShowTrackList ?? () {},
          child: Icon(
            Icons.playlist_play_rounded,
            color: settings.textColor,
            size: isOrientationLandscape ? 24 : 28,
          ),
        ),
      );
      if (withSizedBoxes) buttons.add(SizedBox(width: spacing));
    }

    buttons.add(
      ControlButton(
        settings: settings,
        onTap: onPickAudio,
        child: Icon(
          Icons.swap_horiz_rounded,
          color: settings.textColor,
          size: isOrientationLandscape ? 18 : 20,
        ),
      ),
    );

    return buttons;
  }
}
