import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class PlayPauseButton extends StatelessWidget {
  final ValueNotifier<bool> isPlayingNotifier;
  final VoidCallback onTap;

  const PlayPauseButton({
    super.key,
    required this.isPlayingNotifier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isPlayingNotifier,
      builder: (context, isPlaying, _) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: YomuConstants.accent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
