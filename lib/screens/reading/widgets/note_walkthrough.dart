import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../models/highlight_model.dart';
import 'note_author_avatar.dart';
import 'voice_note_player.dart';
import '../../../components/desktop/adaptive_sheet.dart';

/// Plain text of a note's markdown, for one-line previews.
String notePreview(String? markdown) {
  if (markdown == null) return '';
  return markdown
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '')
      .replaceAll(RegExp(r'[*_`>#~]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// The bar shown while stepping through notes in the text, like a
/// commentary track: who wrote the note, the passage, the note itself and its
/// voice note, with previous / next.
class NoteWalkthroughBar extends StatelessWidget {
  final Highlight note;
  final int index;
  final int count;
  final int replyCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const NoteWalkthroughBar({
    super.key,
    required this.note,
    required this.index,
    required this.count,
    required this.replyCount,
    required this.onPrevious,
    required this.onNext,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final author = note.sharedBy;
    final preview = notePreview(note.note);
    return Material(
      color: const Color(0xF21E1E2E),
      elevation: 12,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                NoteAuthorAvatar(name: author, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${noteAuthorName(author)} · note ${index + 1} of $count',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Stop walking through notes',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“${note.text}”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (note.hasAudio)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: VoiceNotePlayer(
                  key: ValueKey(note.audioFile),
                  fileName: note.audioFile!,
                  durationMs: note.audioDurationMs,
                  waveform: note.audioWaveform,
                  color: noteAuthorColor(author),
                  dense: true,
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous note',
                  onPressed: onPrevious,
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: onPrevious == null ? Colors.white24 : Colors.white,
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: onOpen,
                    child: Text(
                      replyCount > 0
                          ? 'Open · $replyCount '
                                '${replyCount == 1 ? 'reply' : 'replies'}'
                          : 'Open · reply',
                      style: const TextStyle(color: YomuConstants.accent),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next note',
                  onPressed: onNext,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: onNext == null ? Colors.white24 : Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Greets a book that arrived with someone's notes.
Future<bool?> showSharedWelcomeSheet(
  BuildContext context, {
  required String bookTitle,
  required String? sharedBy,
  required int noteCount,
  required int voiceCount,
  required int replyCount,
}) {
  final counts = [
    '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
    if (voiceCount > 0) '$voiceCount ${voiceCount == 1 ? 'voice note' : 'voice notes'}',
    if (replyCount > 0) '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
  ].join(' · ');
  return showAdaptiveSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: YomuConstants.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHandle(),
            const SizedBox(height: 24),
            NoteAuthorAvatar(name: sharedBy ?? '?', size: 56),
            const SizedBox(height: 16),
            Text(
              '${sharedBy ?? 'Someone'} shared notes on',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '“$bookTitle”',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              counts,
              style: const TextStyle(
                color: YomuConstants.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Walk through the notes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: YomuConstants.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Just read',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
