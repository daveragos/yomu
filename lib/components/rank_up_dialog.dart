import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants.dart';

class RankUpDialog extends StatelessWidget {
  final int level;
  final String rankName;

  const RankUpDialog({super.key, required this.level, required this.rankName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      // A card, not a banner: on a wide window the full-width button would
      // otherwise stretch it edge to edge. Phones are narrower than this.
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: YomuConstants.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: YomuConstants.accent, width: 3),
              ),
              child: Center(
                child: Text(
                  '$level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ).animate().scale(
              delay: 200.ms,
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
            const SizedBox(height: 24),
            Text(
              'New rank',
              style: TextStyle(
                color: YomuConstants.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 8),
            Text(
              rankName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 16),
            Text(
              'You\'ve reached a new level of mastery.\nKeep reading to unlock more!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: YomuConstants.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 800.ms),
            const SizedBox(height: 32),
            SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: YomuConstants.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'AWESOME',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 1.seconds)
                .scale(begin: const Offset(0.9, 0.9)),
          ],
        ),
      ),
    );
  }
}
