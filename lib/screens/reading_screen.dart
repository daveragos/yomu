import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  double _playbackProgress = 0.45;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Project Hail Mary', style: TextStyle(fontSize: 16)),
            Text(
              'Andy Weir',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SelectableText.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 20,
                    height: 1.6,
                    letterSpacing: 0.5,
                  ),
                  children: [
                    const TextSpan(text: 'Chapter 1\n\n'),
                    const TextSpan(
                      text: '“What is two plus two?”\n\n',
                      style: TextStyle(
                        backgroundColor: Colors.indigo,
                        color: Colors.white,
                      ),
                    ),
                    const TextSpan(
                      text:
                          'Something about the question irritates me. I am tired. I want to sleep. I want to be left alone.\n\n',
                    ),
                    const TextSpan(
                      text: '“What is two plus two?” the voice asks again.\n\n',
                    ),
                    const TextSpan(
                      text:
                          'It’s a feminine voice. Soft. Pleasant. But there’s a mechanical edge to it. A hint of synthesized cadence.\n\n',
                    ),
                    TextSpan(
                      text:
                          'Lorum ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ' *
                          5,
                      style: TextStyle(color: YomuConstants.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildAudioControls(context),
        ],
      ),
    );
  }

  Widget _buildAudioControls(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      borderRadius: 0,
      blur: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _playbackProgress,
              onChanged: (val) => setState(() => _playbackProgress = val),
              activeColor: YomuConstants.accent,
              inactiveColor: Colors.white24,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('12:45', style: Theme.of(context).textTheme.bodySmall),
                Text('-24:12', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.replay_10), onPressed: () {}),
              IconButton(
                iconSize: 56,
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                color: YomuConstants.accent,
                onPressed: () => setState(() => _isPlaying = !_isPlaying),
              ),
              IconButton(icon: const Icon(Icons.forward_30), onPressed: () {}),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.speed, size: 18),
                label: const Text('1.2x'),
              ),
              const SizedBox(width: 40),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('Sleep'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
