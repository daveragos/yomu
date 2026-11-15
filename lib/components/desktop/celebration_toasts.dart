import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/platform_caps.dart';
import '../../services/celebrations.dart';

/// Shows [Celebrations] as cards in the window's top-right corner, the way
/// desktop apps surface a passing moment instead of a modal dialog: each
/// card slides in, drains a thin timer bar, and fades away. Hovering a card
/// pauses its timer; clicking it dismisses it.
///
/// macOS normally gets a native panel over the whole screen instead (see
/// [Celebrations]); this in-window version covers Windows, Linux, and a Mac
/// build without that panel.
///
/// Phones keep their dialogs and system notifications, so on mobile this
/// only returns [child].
class CelebrationToastHost extends StatefulWidget {
  final Widget child;

  const CelebrationToastHost({super.key, required this.child});

  @override
  State<CelebrationToastHost> createState() => _CelebrationToastHostState();
}

class _CelebrationToastHostState extends State<CelebrationToastHost> {
  /// Past this many, the oldest card leaves early.
  static const _maxVisible = 3;

  final List<({int id, Celebration celebration})> _toasts = [];
  StreamSubscription<Celebration>? _subscription;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    if (!PlatformCaps.isDesktop) return;
    _subscription = Celebrations.stream.listen((celebration) {
      setState(() {
        _toasts.add((id: _nextId++, celebration: celebration));
        if (_toasts.length > _maxVisible) _toasts.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _remove(int id) {
    setState(() => _toasts.removeWhere((t) => t.id == id));
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformCaps.isDesktop) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: PlatformCaps.titleBarInset + 12,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final toast in _toasts)
                Padding(
                  key: ValueKey(toast.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CelebrationCard(
                    celebration: toast.celebration,
                    onDone: () => _remove(toast.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CelebrationCard extends StatefulWidget {
  final Celebration celebration;
  final VoidCallback onDone;

  const _CelebrationCard({required this.celebration, required this.onDone});

  @override
  State<_CelebrationCard> createState() => _CelebrationCardState();
}

class _CelebrationCardState extends State<_CelebrationCard>
    with TickerProviderStateMixin {
  static const _life = Duration(seconds: 12);

  /// Runs from full to empty over the card's life; the bar is drawn from it.
  late final AnimationController _timer =
      AnimationController(vsync: this, duration: _life)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _leave();
        });

  /// Slides and fades the card in, and fades and shrinks it on the way out.
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  bool _hovered = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _presence.forward().then((_) {
      if (mounted && !_leaving && !_hovered) _timer.forward();
    });
  }

  @override
  void dispose() {
    _timer.dispose();
    _presence.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _timer.stop();
    await _presence.reverse();
    if (mounted) widget.onDone();
  }

  IconData get _icon => switch (widget.celebration.kind) {
    CelebrationKind.achievement => Icons.emoji_events_outlined,
    CelebrationKind.quest => Icons.task_alt_rounded,
    CelebrationKind.level => Icons.trending_up_rounded,
    CelebrationKind.rank => Icons.military_tech_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final presence = CurvedAnimation(
      parent: _presence,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: YomuConstants.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon, size: 18, color: YomuConstants.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.celebration.title,
                            style: const TextStyle(
                              color: YomuConstants.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.celebration.body,
                            style: const TextStyle(
                              color: YomuConstants.textSecondary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _timer,
                builder: (context, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 1 - _timer.value,
                    child: Container(height: 2, color: YomuConstants.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return FadeTransition(
      opacity: presence,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).animate(presence),
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(presence),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              _hovered = true;
              _timer.stop();
            },
            onExit: (_) {
              _hovered = false;
              if (!_leaving && _presence.isCompleted) _timer.forward();
            },
            child: GestureDetector(onTap: _leave, child: card),
          ),
        ),
      ),
    );
  }
}
