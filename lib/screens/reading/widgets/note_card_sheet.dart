import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../models/annotation_reply_model.dart';
import '../../../models/highlight_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../services/annotation_audio_service.dart';
import '../../../services/database_service.dart';
import 'highlight_toolbar.dart';
import 'note_author_avatar.dart';
import 'note_view.dart';
import 'voice_note_player.dart';
import 'voice_note_recorder.dart';
import '../../../components/desktop/adaptive_sheet.dart';

/// Shows a highlight with everything attached to it: who wrote it, the
/// passage, the note, the voice note and the replies, with a box to reply.
///
/// [onUpdate] saves changes to the highlight (note, colour, voice note,
/// private), [onDelete] removes it. [onGoTo] adds a "Go to" button, for
/// cards opened away from the text.
Future<void> showNoteCard(
  BuildContext context, {
  required Highlight highlight,
  required ReaderSettings settings,
  required Future<void> Function(Highlight highlight) onUpdate,
  required Future<void> Function(int id) onDelete,
  String? location,
  VoidCallback? onGoTo,
}) {
  return showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    maxPanelWidth: 460,
    builder: (context) => NoteCardSheet(
      highlight: highlight,
      settings: settings,
      onUpdate: onUpdate,
      onDelete: onDelete,
      location: location,
      onGoTo: onGoTo,
    ),
  );
}

class NoteCardSheet extends StatefulWidget {
  final Highlight highlight;
  final ReaderSettings settings;
  final Future<void> Function(Highlight highlight) onUpdate;
  final Future<void> Function(int id) onDelete;
  final String? location;
  final VoidCallback? onGoTo;

  const NoteCardSheet({
    super.key,
    required this.highlight,
    required this.settings,
    required this.onUpdate,
    required this.onDelete,
    this.location,
    this.onGoTo,
  });

  @override
  State<NoteCardSheet> createState() => _NoteCardSheetState();
}

class _NoteCardSheetState extends State<NoteCardSheet> {
  final _db = DatabaseService();
  final _replyController = TextEditingController();
  late Highlight _highlight = widget.highlight;
  List<AnnotationReply> _replies = const [];

  /// Voice recording for the reply being written; deleted unless sent.
  String? _draftAudio;
  int? _draftAudioMs;
  String? _draftWaveform;
  bool _sending = false;

  Color get _color {
    final value = int.tryParse(_highlight.color.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0xF1C40F));
  }

  @override
  void initState() {
    super.initState();
    _loadReplies();
    _replyController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_draftAudio != null) AnnotationAudioService.delete(_draftAudio);
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    final uid = _highlight.uid;
    if (uid == null) return;
    final all = await _db.getRepliesForBook(_highlight.bookId);
    if (!mounted) return;
    setState(() {
      _replies = all.where((r) => r.highlightUid == uid).toList();
    });
  }

  Future<void> _save(Highlight updated) async {
    await widget.onUpdate(updated);
    if (mounted) setState(() => _highlight = updated);
  }

  void _edit() {
    final existing = _highlight;
    showHighlightNoteSheet(
      context,
      settings: widget.settings,
      existing: existing,
      onSave: (result) => _save(
        existing.copyWith(
          note: result.markdown,
          color: result.color ?? existing.color,
          audioFile: result.audioFile,
          audioDurationMs: result.audioDurationMs,
          audioWaveform: result.audioWaveform,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final hasContent =
        _highlight.hasNote || _highlight.hasAudio || _replies.isNotEmpty;
    if (hasContent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: YomuConstants.surface,
          title: const Text(
            'Delete this note?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'The highlight, its note, voice note and replies are removed.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('KEEP'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'DELETE',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await widget.onDelete(_highlight.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if ((text.isEmpty && _draftAudio == null) || _sending) return;
    setState(() => _sending = true);
    try {
      var parent = _highlight;
      if (parent.uid == null) {
        parent = parent.copyWith(uid: Highlight.generateUid());
        await _save(parent);
      }
      await _db.insertReply(
        AnnotationReply(
          bookId: parent.bookId,
          highlightUid: parent.uid!,
          uid: AnnotationReply.generateUid(),
          text: text,
          audioFile: _draftAudio,
          audioDurationMs: _draftAudio == null ? null : _draftAudioMs,
          audioWaveform: _draftAudio == null ? null : _draftWaveform,
          createdAt: DateTime.now(),
        ),
      );
      // The recording now belongs to the reply; don't delete it on close.
      _draftAudio = null;
      _draftAudioMs = null;
      _draftWaveform = null;
      _replyController.clear();
      if (!mounted) return;
      setState(() {});
      FocusScope.of(context).unfocus();
      await _loadReplies();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteReply(AnnotationReply reply) async {
    await _db.deleteReply(reply.id!);
    await _loadReplies();
  }

  String _date(DateTime d) =>
      '${d.day}/${d.month}/${d.year % 100} '
      '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final h = _highlight;
    final author = h.sharedBy;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: widget.settings.menuBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SheetHandle(margin: const EdgeInsets.only(top: 12, bottom: 8)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  children: [
                    _buildHeader(author),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: _color, width: 3),
                        ),
                      ),
                      child: Text(
                        h.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    if (h.isUnplaced) ...[
                      const SizedBox(height: 12),
                      const _Hint(
                        icon: Icons.location_off_outlined,
                        text:
                            "This passage wasn't found in your copy of the "
                            'book, so it is only listed here.',
                      ),
                    ],
                    if (h.hasNote) ...[
                      const SizedBox(height: 16),
                      NoteView(
                        markdown: h.note!,
                        settings: widget.settings,
                        fontSize: 15,
                        textColor: Colors.white70,
                      ),
                    ],
                    if (h.hasAudio) ...[
                      const SizedBox(height: 16),
                      VoiceNotePlayer(
                        fileName: h.audioFile!,
                        durationMs: h.audioDurationMs,
                        waveform: h.audioWaveform,
                        color: noteAuthorColor(author),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildActions(),
                    const Divider(color: Colors.white10, height: 24),
                    _buildReplies(),
                  ],
                ),
              ),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? author) {
    final h = _highlight;
    return Row(
      children: [
        NoteAuthorAvatar(name: author, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                noteAuthorName(author),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                [
                  if (widget.location != null) widget.location!,
                  _date(h.createdAt),
                ].join(' · '),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        if (h.isPrivate)
          const Tooltip(
            message: 'Private: left out when you share',
            child: Icon(Icons.lock_outline, color: Colors.white38, size: 18),
          ),
        const SizedBox(width: 8),
        Icon(Icons.circle, color: _color, size: 14),
      ],
    );
  }

  Widget _buildActions() {
    final h = _highlight;
    Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) {
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color ?? Colors.white70),
        label: Text(
          label,
          style: TextStyle(color: color ?? Colors.white70, fontSize: 13),
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 0,
      children: [
        if (widget.onGoTo != null)
          action(Icons.my_location_rounded, 'Go to', () {
            Navigator.pop(context);
            widget.onGoTo!();
          }, color: YomuConstants.accent),
        action(
          h.hasNote || h.hasAudio ? Icons.edit_outlined : Icons.edit_note_rounded,
          h.hasNote || h.hasAudio ? 'Edit' : 'Add note',
          _edit,
        ),
        action(
          h.isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
          h.isPrivate ? 'Private' : 'Shared',
          () => _save(h.copyWith(isPrivate: !h.isPrivate)),
          color: h.isPrivate ? YomuConstants.accent : null,
        ),
        action(Icons.delete_outline, 'Delete', _delete, color: Colors.redAccent),
      ],
    );
  }

  Widget _buildReplies() {
    if (_replies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text(
          'No replies yet. Your reply goes along when you share the book.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_replies.length} ${_replies.length == 1 ? 'REPLY' : 'REPLIES'}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        for (final reply in _replies) _buildReply(reply),
      ],
    );
  }

  Widget _buildReply(AnnotationReply reply) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoteAuthorAvatar(name: reply.author, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${noteAuthorName(reply.author)} · ${_date(reply.createdAt)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (reply.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reply.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
                if (reply.hasAudio) ...[
                  const SizedBox(height: 6),
                  VoiceNotePlayer(
                    fileName: reply.audioFile!,
                    durationMs: reply.audioDurationMs,
                    waveform: reply.audioWaveform,
                    color: noteAuthorColor(reply.author),
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
          if (reply.isMine)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete reply',
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.white30,
                size: 18,
              ),
              onPressed: () => _deleteReply(reply),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final canSend =
        !_sending &&
        (_replyController.text.trim().isNotEmpty || _draftAudio != null);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Reply…',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send reply',
                onPressed: canSend ? _sendReply : null,
                icon: Icon(
                  Icons.send_rounded,
                  color: canSend ? YomuConstants.accent : Colors.white24,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: VoiceNoteRecorder(
              fileName: _draftAudio,
              durationMs: _draftAudioMs,
              waveform: _draftWaveform,
              prompt: 'Reply with your voice',
              onRecorded: (fileName, durationMs, waveform) {
                if (_draftAudio != null) {
                  AnnotationAudioService.delete(_draftAudio);
                }
                setState(() {
                  _draftAudio = fileName;
                  _draftAudioMs = durationMs;
                  _draftWaveform = waveform;
                });
              },
              onRemoved: () {
                AnnotationAudioService.delete(_draftAudio);
                setState(() {
                  _draftAudio = null;
                  _draftAudioMs = null;
                  _draftWaveform = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.amberAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
