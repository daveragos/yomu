import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../screens/reading/widgets/note_author_avatar.dart';
import '../services/annotation_share_service.dart';

/// Notes shared without their book, shown in the library so they aren't
/// forgotten: place them on another copy, add the book, or discard them.
class PendingNotesBanner extends StatefulWidget {
  final List<PendingNotes> pending;
  final void Function(PendingNotes notes) onPlace;
  final VoidCallback onAddBook;
  final void Function(PendingNotes notes) onDiscard;

  const PendingNotesBanner({
    super.key,
    required this.pending,
    required this.onPlace,
    required this.onAddBook,
    required this.onDiscard,
  });

  @override
  State<PendingNotesBanner> createState() => _PendingNotesBannerState();
}

class _PendingNotesBannerState extends State<PendingNotesBanner> {
  bool _expanded = false;

  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final count = widget.pending.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: YomuConstants.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        count == 1
                            ? 'Notes waiting for a book'
                            : '$count sets of notes waiting for their books',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.white54,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 4),
                  for (final notes in widget.pending) _buildRow(notes),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(PendingNotes notes) {
    final m = notes.manifest;
    final noteCount = m.annotations.length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NoteAuthorAvatar(name: m.sharedBy ?? '?', size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m.sharedBy ?? 'Someone'} · "${m.title}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Text(
                      '$noteCount ${noteCount == 1 ? 'note' : 'notes'} · '
                      'received ${_date(notes.receivedAt)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            children: [
              if (notes.similarBook != null)
                TextButton(
                  onPressed: () => widget.onPlace(notes),
                  child: const Text(
                    'Place on my copy',
                    style: TextStyle(color: YomuConstants.accent),
                  ),
                )
              else
                TextButton(
                  onPressed: widget.onAddBook,
                  child: const Text(
                    'Add the book',
                    style: TextStyle(color: YomuConstants.accent),
                  ),
                ),
              TextButton(
                onPressed: () => widget.onDiscard(notes),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
