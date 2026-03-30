import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../core/constants.dart';
import '../../../models/reader_settings_model.dart';

class NoteEditor extends StatefulWidget {
  final String initialMarkdown;
  final Function(String) onSave;
  final ReaderSettings? settings;
  final String title;

  const NoteEditor({
    super.key,
    required this.initialMarkdown,
    required this.onSave,
    this.settings,
    this.title = 'Edit Note',
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    if (widget.initialMarkdown.isEmpty) {
      _controller = QuillController.basic();
    } else {
      try {
        Document doc;
        if (widget.initialMarkdown.trim().startsWith('[{') && widget.initialMarkdown.trim().endsWith('}]')) {
          // Legacy JSON format check
          try {
            doc = Document.fromJson(jsonDecode(widget.initialMarkdown));
          } catch (_) {
            doc = _parseMarkdown(widget.initialMarkdown);
          }
        } else {
          doc = _parseMarkdown(widget.initialMarkdown);
        }

        _controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        debugPrint('Error loading document: $e');
        _controller = QuillController.basic();
      }
    }
    _controller.readOnly = false;
  }

  Document _parseMarkdown(String markdownText) {
    final mdDocument = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    final mdToDelta = MarkdownToDelta(markdownDocument: mdDocument);
    final delta = mdToDelta.convert(markdownText);
    return Document.fromDelta(delta);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSave() {
    final deltaToMd = DeltaToMarkdown();
    final markdown = deltaToMd.convert(_controller.document.toDelta());
    widget.onSave(markdown);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: widget.settings?.menuBackgroundColor ?? YomuConstants.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: YomuConstants.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _onSave();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'SAVE',
                    style: TextStyle(
                      color: YomuConstants.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          QuillSimpleToolbar(
            controller: _controller,
            config: QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              showAlignmentButtons: false,
              showDirection: false,
              showFontFamily: false,
              showFontSize: false,
              showBoldButton: true,
              showItalicButton: true,
              showSmallButton: false,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showInlineCode: true,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: true,
              showLink: true,
              showListCheck: true,
              showCodeBlock: true,
              showQuote: true,
              showListNumbers: true,
              showListBullets: true,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showIndent: false,
              buttonOptions: QuillSimpleToolbarButtonOptions(
                base: QuillToolbarBaseButtonOptions(
                  iconTheme: QuillIconTheme(
                    iconButtonUnselectedData: IconButtonData(
                      color: Colors.white70,
                    ),
                    iconButtonSelectedData: IconButtonData(
                      color: YomuConstants.accent,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            YomuConstants.accent.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: QuillEditor(
                controller: _controller,
                focusNode: _focusNode,
                scrollController: ScrollController(),
                config: QuillEditorConfig(
                  padding: EdgeInsets.zero,
                  autoFocus: true,
                  expands: false,
                  placeholder: 'Write something amazing...',
                  customStyles: DefaultStyles(
                    paragraph: DefaultTextBlockStyle(
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.6,
                      ),
                      const HorizontalSpacing(0, 0),
                      const VerticalSpacing(0, 0),
                      const VerticalSpacing(0, 0),
                      null,
                    ),
                    placeHolder: DefaultTextBlockStyle(
                      const TextStyle(
                        color: Colors.white24,
                        fontSize: 18,
                      ),
                      const HorizontalSpacing(0, 0),
                      const VerticalSpacing(0, 0),
                      const VerticalSpacing(0, 0),
                      null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
