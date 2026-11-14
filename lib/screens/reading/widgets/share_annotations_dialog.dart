import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class ShareAnnotationsOptions {
  final String name;
  final bool includeBook;

  const ShareAnnotationsOptions({required this.name, required this.includeBook});
}

/// Asks how to share a book with its annotations: the name readers will see
/// on the notes, and whether to send the book file along.
class ShareAnnotationsDialog extends StatefulWidget {
  final String bookTitle;
  final int annotationCount;
  final int voiceNoteCount;
  final String? initialName;

  const ShareAnnotationsDialog({
    super.key,
    required this.bookTitle,
    required this.annotationCount,
    required this.voiceNoteCount,
    this.initialName,
  });

  static Future<ShareAnnotationsOptions?> show(
    BuildContext context, {
    required String bookTitle,
    required int annotationCount,
    required int voiceNoteCount,
    String? initialName,
  }) {
    return showDialog<ShareAnnotationsOptions>(
      context: context,
      builder: (context) => ShareAnnotationsDialog(
        bookTitle: bookTitle,
        annotationCount: annotationCount,
        voiceNoteCount: voiceNoteCount,
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  void _submit() {
    if (_name.isEmpty) return;
    Navigator.pop(
      context,
      ShareAnnotationsOptions(name: _name, includeBook: _includeBook),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.annotationCount;
    final voice = widget.voiceNoteCount;
    final summary = [
      '$notes ${notes == 1 ? 'annotation' : 'annotations'}',
      if (voice > 0) '$voice ${voice == 1 ? 'voice note' : 'voice notes'}',
    ].join(' · ');

    return AlertDialog(
      backgroundColor: YomuConstants.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Share with annotations',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anyone who opens this file in Yomu sees your highlights, notes '
              'and voice notes on "${widget.bookTitle}".',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              summary,
              style: const TextStyle(
                color: YomuConstants.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 8),
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
                    ? 'Readers can open it right away.'
                    : 'Smaller file. Readers need the exact same copy of the '
                          'book; notes appear once they add it.',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _name.isEmpty ? null : _submit,
          child: Text(
            'SHARE',
            style: TextStyle(
              color: _name.isEmpty ? Colors.white24 : YomuConstants.accent,
            ),
          ),
        ),
      ],
    );
  }
}
