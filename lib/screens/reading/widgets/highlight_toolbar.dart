import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../models/highlight_model.dart';
import '../../../models/reader_settings_model.dart';
import 'note_editor.dart';
import 'voice_note_player.dart';

/// `#RRGGBB` for a highlight colour, as stored in [Highlight.color].
String highlightHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

const defaultHighlightColor = '#F1C40F';

/// The menu shown over selected or highlighted text, shared by the EPUB and
/// PDF readers: colour dots (plus Remove for an existing highlight), then
/// Note, Play voice note, Copy, Dictionary and Share.
class HighlightToolbar extends StatelessWidget {
  final ReaderSettings settings;
  final ValueChanged<String> onColor;
  final VoidCallback? onRemove;
  final VoidCallback onNote;
  final VoidCallback? onPlayVoiceNote;
  final VoidCallback onCopy;
  final VoidCallback? onLookup;
  final VoidCallback onShare;

  /// Widest layout: five colour dots plus Remove, 36 px each, and padding.
  static const width = 224.0;
  static const height = 80.0;

  const HighlightToolbar({
    super.key,
    required this.settings,
    required this.onColor,
    required this.onNote,
    required this.onCopy,
    required this.onShare,
    this.onRemove,
    this.onPlayVoiceNote,
    this.onLookup,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = settings.menuIconColor;
    const btnSize = 36.0;
    const iconSize = 20.0;

    Widget button(
      IconData icon,
      Color color,
      VoidCallback onPressed, {
      String? tooltip,
      double size = iconSize,
    }) {
      return SizedBox(
        width: btnSize,
        height: btnSize,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: tooltip,
          icon: Icon(icon, color: color, size: size),
          onPressed: onPressed,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: settings.menuBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in YomuConstants.highlightColors)
                  button(
                    Icons.circle,
                    color,
                    () => onColor(highlightHex(color)),
                    size: 22,
                  ),
                if (onRemove != null)
                  button(Icons.highlight_remove, textColor, onRemove!),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button(
                  Icons.sticky_note_2_rounded,
                  YomuConstants.accent,
                  onNote,
                ),
                if (onPlayVoiceNote != null)
                  button(
                    Icons.graphic_eq_rounded,
                    YomuConstants.accent,
                    onPlayVoiceNote!,
                    tooltip: 'Play voice note',
                  ),
                button(Icons.copy_rounded, textColor, onCopy),
                if (onLookup != null)
                  button(Icons.menu_book_rounded, textColor, onLookup!),
                button(Icons.share_rounded, textColor, onShare),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the note editor for a new or existing highlight.
void showHighlightNoteSheet(
  BuildContext context, {
  required ReaderSettings settings,
  required Highlight? existing,
  required ValueChanged<NoteEditorResult> onSave,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => NoteEditor(
      initialMarkdown: existing?.note ?? '',
      initialColor: existing?.color ?? defaultHighlightColor,
      initialAudioFile: existing?.audioFile,
      initialAudioDurationMs: existing?.audioDurationMs,
      initialAudioWaveform: existing?.audioWaveform,
      settings: settings,
      title: existing != null ? 'Edit Note' : 'Add Note',
      subtitle: existing?.sharedBy != null
          ? 'Shared by ${existing!.sharedBy}'
          : null,
      onSave: onSave,
    ),
  );
}

/// Plays a highlight's voice note in a bottom sheet.
void showVoiceNoteSheet(
  BuildContext context, {
  required ReaderSettings settings,
  required Highlight highlight,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: settings.menuBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              highlight.sharedBy != null
                  ? 'VOICE NOTE FROM ${highlight.sharedBy!.toUpperCase()}'
                  : 'VOICE NOTE',
              style: const TextStyle(
                color: YomuConstants.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              highlight.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            VoiceNotePlayer(
              fileName: highlight.audioFile!,
              durationMs: highlight.audioDurationMs,
              waveform: highlight.audioWaveform,
            ),
          ],
        ),
      ),
    ),
  );
}
