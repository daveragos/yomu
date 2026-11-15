import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../models/reader_settings_model.dart';
import '../../../core/yomu_colors.dart';

class NoteView extends StatelessWidget {
  final String markdown;
  final ReaderSettings settings;
  final double? fontSize;
  final Color? textColor;

  const NoteView({
    super.key,
    required this.markdown,
    required this.settings,
    this.fontSize,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.yomu;
    if (markdown.trim().isEmpty) {
      return Text(
        'No content',
        style: TextStyle(color: colors.tint(0.38), fontStyle: FontStyle.italic),
      );
    }

    Document doc;
    if (markdown.trim().startsWith('[{') && markdown.trim().endsWith('}]')) {
      try {
        doc = Document.fromJson(jsonDecode(markdown));
      } catch (_) {
        doc = _parseMarkdown(markdown);
      }
    } else {
      doc = _parseMarkdown(markdown);
    }

    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

    return QuillEditor.basic(
      controller: controller,
      config: QuillEditorConfig(
        autoFocus: false,
        expands: false,
        padding: EdgeInsets.zero,
        showCursor: false,
        enableInteractiveSelection: true,
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            TextStyle(
              color: textColor ?? settings.textColor.withValues(alpha: 0.7),
              fontSize: fontSize ?? 16,
              height: 1.6,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            null,
          ),
          h1: DefaultTextBlockStyle(
            TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(16, 0),
            const VerticalSpacing(0, 0),
            null,
          ),
          bold: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
          italic: const TextStyle(
            fontStyle: FontStyle.italic,
          ),
          strikeThrough: const TextStyle(
            decoration: TextDecoration.lineThrough,
          ),
          link: TextStyle(
            color: colors.accent,
            decoration: TextDecoration.underline,
          ),
          quote: DefaultTextBlockStyle(
            TextStyle(
              color: colors.tint(0.70),
              fontSize: fontSize ?? 16,
              fontStyle: FontStyle.italic,
            ),
            const HorizontalSpacing(12, 0),
            const VerticalSpacing(8, 8),
            const VerticalSpacing(0, 0),
            BoxDecoration(
              border: Border(
                left: BorderSide(color: colors.accent, width: 4),
              ),
            ),
          ),
          code: DefaultTextBlockStyle(
            TextStyle(
              color: colors.accent,
              backgroundColor: colors.tint(0.1),
              fontFamily: 'monospace',
              fontSize: (fontSize ?? 16) - 2,
            ),
            const HorizontalSpacing(12, 12),
            const VerticalSpacing(4, 4),
            const VerticalSpacing(0, 0),
            null,
          ),
        ),
      ),
    );
  }

  Document _parseMarkdown(String markdownText) {
    if (markdownText.trim().isEmpty) return Document();

    final mdDocument = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    final mdToDelta = MarkdownToDelta(markdownDocument: mdDocument);
    final delta = mdToDelta.convert(markdownText);
    if (delta.isEmpty) return Document();
    return Document.fromDelta(delta);
  }
}
