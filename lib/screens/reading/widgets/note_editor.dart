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
    this.initialColor,
    this.onSaveWithColor,
  });

  final String? initialColor;
  final Function(String, String)? onSaveWithColor;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  String? _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
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

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSave() {
    final deltaToMd = DeltaToMarkdown();
    final markdown = deltaToMd.convert(_controller.document.toDelta());
    if (widget.onSaveWithColor != null && _currentColor != null) {
      widget.onSaveWithColor!(markdown, _currentColor!);
    } else {
      widget.onSave(markdown);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: widget.settings?.menuBackgroundColor ?? YomuConstants.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            const SizedBox(height: 12),
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
            if (_currentColor != null) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: YomuConstants.highlightColors.map((color) {
                    final hexColor = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                    final isSelected = _currentColor == hexColor;
                    return GestureDetector(
                      onTap: () => setState(() => _currentColor = hexColor),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.black)
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                showUnderLineButton: false,
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
      ),
    );
  }
}
