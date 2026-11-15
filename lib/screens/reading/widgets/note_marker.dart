import 'package:flutter/material.dart';
import '../../../models/highlight_model.dart';
import 'note_author_avatar.dart';

/// The little badge after a highlight in the text that has something to open:
/// a note, a voice note, replies, or someone else's name on it.
class NoteMarker extends StatelessWidget {
  final Highlight highlight;
  final int replyCount;
  final VoidCallback onTap;
  final double size;

  const NoteMarker({
    super.key,
    required this.highlight,
    required this.replyCount,
    required this.onTap,
    this.size = 16,
  });

  static bool shows(Highlight h, int replyCount) =>
      h.hasNote || h.hasAudio || replyCount > 0 || h.isShared;

  /// The icon that says what the note holds, most telling first.
  static IconData iconFor(Highlight h, int replyCount) {
    if (h.hasAudio) return Icons.graphic_eq_rounded;
    if (h.hasNote) return Icons.sticky_note_2_rounded;
    if (replyCount > 0) return Icons.chat_bubble_rounded;
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final author = highlight.sharedBy;
    final color = noteAuthorColor(author);
    final initial = author?.trim().characters.firstOrNull?.toUpperCase();
    final what = [
      if (highlight.hasAudio) 'voice note',
      if (highlight.hasNote) 'note',
      if (replyCount > 0) '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
    ];
    return Semantics(
      button: true,
      label:
          'Open ${what.isEmpty ? 'highlight' : what.join(', ')}'
          '${author != null ? ' from $author' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // A bigger target than the badge itself.
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Container(
            height: size,
            padding: EdgeInsets.symmetric(horizontal: size * 0.22),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(size / 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconFor(highlight, replyCount),
                  size: size * 0.68,
                  color: Colors.white,
                ),
                if (initial != null) ...[
                  SizedBox(width: size * 0.12),
                  Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.6,
                      height: 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (replyCount > 0 && (highlight.hasAudio || highlight.hasNote)) ...[
                  SizedBox(width: size * 0.15),
                  Icon(
                    Icons.chat_bubble_rounded,
                    size: size * 0.5,
                    color: Colors.white,
                  ),
                  Text(
                    '$replyCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.55,
                      height: 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
