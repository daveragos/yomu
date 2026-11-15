import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../components/desktop/page_header.dart';
import '../../../core/breakpoints.dart';
import '../../../core/constants.dart';

class EmptyLibraryView extends ConsumerWidget {
  final VoidCallback onImportFiles;

  const EmptyLibraryView({super.key, required this.onImportFiles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Breakpoints.isWide(context)) return _buildWide();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text('Your library is empty'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onImportFiles,
            style: ElevatedButton.styleFrom(
              backgroundColor: YomuConstants.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Books',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// A centered welcome card instead of a lone icon floating in a large
  /// window: what Yomu reads, what it tracks, and the one action to take.
  Widget _buildWide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.fromLTRB(36, 40, 36, 32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: YomuConstants.textSecondary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your library is empty',
                  style: TextStyle(
                    color: YomuConstants.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Add EPUB or PDF books to start reading. Yomu keeps your '
                  'place, streak and XP as you go.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: YomuConstants.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                DesktopPrimaryButton(
                  icon: Icons.add_rounded,
                  label: 'Add books',
                  onPressed: onImportFiles,
                ),
                const SizedBox(height: 16),
                Text(
                  'Supports EPUB and PDF',
                  style: TextStyle(
                    color: YomuConstants.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
