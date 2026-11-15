import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../models/highlight_model.dart';
import '../../../utils/annotation_order.dart';
import 'note_author_avatar.dart';

class ShareAnnotationsOptions {
  final String name;
  final bool includeBook;

  /// Uids of the notes to share.
  final Set<String> uids;

  const ShareAnnotationsOptions({
    required this.name,
    required this.includeBook,
    required this.uids,
  });
}

/// "1.4 MB", "820 KB".
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}

/// Asks how to share a book with its notes: the name readers will see,
/// whether to send the book file along, and which notes to include.
class ShareAnnotationsDialog extends StatefulWidget {
  final String bookTitle;
  final bool isPdf;

  /// The book's notes in reading order. Private ones are shown but can't be
  /// picked.
  final List<Highlight> highlights;

  /// Replies per note uid.
  final Map<String, int> replyCounts;

  /// Voice note bytes per note uid, its replies' included.
  final Map<String, int> voiceBytes;
  final int bookBytes;
  final String? initialName;

  const ShareAnnotationsDialog({
    super.key,
    required this.bookTitle,
    required this.isPdf,
    required this.highlights,
    required this.replyCounts,
    required this.voiceBytes,
    required this.bookBytes,
    this.initialName,
  });

  static Future<ShareAnnotationsOptions?> show(
    BuildContext context, {
    required String bookTitle,
    required bool isPdf,
    required List<Highlight> highlights,
    required Map<String, int> replyCounts,
    required Map<String, int> voiceBytes,
    required int bookBytes,
    String? initialName,
  }) {
    return showDialog<ShareAnnotationsOptions>(
      context: context,
      builder: (context) => ShareAnnotationsDialog(
        bookTitle: bookTitle,
        isPdf: isPdf,
        highlights: highlights,
        replyCounts: replyCounts,
        voiceBytes: voiceBytes,
        bookBytes: bookBytes,
        initialName: initialName,
      ),
    );
  }

  @override
  State<ShareAnnotationsDialog> createState() => _ShareAnnotationsDialogState();
}

class _ShareAnnotationsDialogState extends State<ShareAnnotationsDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName ?? '',
  );
  bool _includeBook = true;
  bool _choosing = false;

  late final List<Highlight> _shareable = widget.highlights
      .where((h) => !h.isPrivate && h.uid != null)
      .toList();
  late final Set<String> _selected = {for (final h in _shareable) h.uid!};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  bool get _canShare =>
      _name.isNotEmpty && (_includeBook || _selected.isNotEmpty);

  void _submit() {
    if (!_canShare) return;
    Navigator.pop(
      context,
      ShareAnnotationsOptions(
        name: _name,
        includeBook: _includeBook,
        uids: {..._selected},
      ),
    );
  }

  int get _estimatedBytes {
    var bytes = _includeBook ? widget.bookBytes : 0;
    for (final uid in _selected) {
      bytes += widget.voiceBytes[uid] ?? 0;
    }
    // The notes themselves are small: allow for the list and zip headers.
    return bytes + 2048 + _selected.length * 400;
  }

  String _summary() {
    final chosen = _shareable.where((h) => _selected.contains(h.uid)).toList();
    final voice = chosen.where((h) => h.hasAudio).length;
    final replies = chosen.fold<int>(
      0,
      (sum, h) => sum + (widget.replyCounts[h.uid] ?? 0),
    );
    final privateCount = widget.highlights.where((h) => h.isPrivate).length;
    return [
      chosen.length == _shareable.length
          ? '${chosen.length} ${chosen.length == 1 ? 'note' : 'notes'}'
          : '${chosen.length} of ${_shareable.length} notes',
      if (voice > 0) '$voice ${voice == 1 ? 'voice note' : 'voice notes'}',
      if (replies > 0) '$replies ${replies == 1 ? 'reply' : 'replies'}',
      if (privateCount > 0) '$privateCount private',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: YomuConstants.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Share with notes',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anyone who opens this file in Yomu sees your highlights, '
                'notes and voice notes on "${widget.bookTitle}".',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: (widget.initialName ?? '').isEmpty,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  helperText: 'Shown to readers next to your notes',
                  labelStyle: TextStyle(color: Colors.white54),
                  helperStyle: TextStyle(color: Colors.white38),
                  counterStyle: TextStyle(color: Colors.white24),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: YomuConstants.accent),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                value: _includeBook,
                onChanged: (v) => setState(() => _includeBook = v),
                activeThumbColor: YomuConstants.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Include the book file',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  _includeBook
                      ? 'Sent as the book itself, so it opens from any chat or '
                            'file app. Other reading apps just show the book.'
                      : 'A small .yomu file with only your notes. Readers need '
                            'a copy of the same book; notes appear once they '
                            'add it.',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              const Divider(color: Colors.white10),
              InkWell(
                onTap: _shareable.isEmpty
                    ? null
                    : () => setState(() => _choosing = !_choosing),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _summary(),
                          style: const TextStyle(
                            color: YomuConstants.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_shareable.isNotEmpty)
                        Text(
                          _choosing ? 'DONE' : 'CHOOSE',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_choosing) _buildChooser(),
              Text(
                'About ${formatFileSize(_estimatedBytes)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _canShare ? _submit : null,
          child: Text(
            'SHARE',
            style: TextStyle(
              color: _canShare ? YomuConstants.accent : Colors.white24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChooser() {
    final all = _selected.length == _shareable.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() {
              all
                  ? _selected.clear()
                  : _selected.addAll(_shareable.map((h) => h.uid!));
            }),
            child: Text(
              all ? 'Select none' : 'Select all',
              style: const TextStyle(color: YomuConstants.accent, fontSize: 12),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final h in widget.highlights) _buildNoteRow(h),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNoteRow(Highlight h) {
    final selectable = !h.isPrivate && h.uid != null;
    final replies = widget.replyCounts[h.uid] ?? 0;
    final details = [
      AnnotationOrder.location(h, isPdf: widget.isPdf),
      if (h.isShared) noteAuthorName(h.sharedBy),
      if (h.isPrivate) 'Private',
    ].join(' · ');
    return CheckboxListTile(
      value: selectable && _selected.contains(h.uid),
      onChanged: selectable
          ? (v) => setState(() {
              v == true ? _selected.add(h.uid!) : _selected.remove(h.uid);
            })
          : null,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: YomuConstants.accent,
      title: Text(
        h.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selectable ? Colors.white : Colors.white38,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        details,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (h.isPrivate)
            const Icon(Icons.lock_outline, size: 16, color: Colors.white38),
          if (h.hasAudio)
            const Icon(Icons.graphic_eq_rounded, size: 16, color: Colors.white54),
          if (h.hasNote)
            const Icon(Icons.notes_rounded, size: 16, color: Colors.white54),
          if (replies > 0) ...[
            const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white54),
            Text(
              ' $replies',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
