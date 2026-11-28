import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../core/breakpoints.dart';
import '../../../core/constants.dart';
import '../../../core/yomu_colors.dart';
import '../../../models/reader_settings_model.dart';
import '../../../services/annotation_audio_service.dart';
import 'voice_note_recorder.dart';
import '../../../components/desktop/adaptive_sheet.dart';

class NoteEditorResult {
  final String markdown;
  final String? color;
  final String? audioFile;
  final int? audioDurationMs;
  final String? audioWaveform;

  const NoteEditorResult({
    required this.markdown,
    this.color,
    this.audioFile,
    this.audioDurationMs,
    this.audioWaveform,
  });
}

class NoteEditor extends StatefulWidget {
  final String initialMarkdown;
  final void Function(NoteEditorResult result) onSave;
  final ReaderSettings? settings;
  final String title;
  final String? subtitle;
  final String? initialColor;
  final String? initialAudioFile;
  final int? initialAudioDurationMs;
  final String? initialAudioWaveform;

  const NoteEditor({
    super.key,
    required this.initialMarkdown,
    required this.onSave,
    this.settings,
    this.title = 'Edit Note',
    this.subtitle,
    this.initialColor,
    this.initialAudioFile,
    this.initialAudioDurationMs,
    this.initialAudioWaveform,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  String? _currentColor;
  String? _audioFile;
  int? _audioDurationMs;
  String? _audioWaveform;
  bool _saved = false;

  /// Recordings made while this editor was open. Any that are not kept when
  /// the note is saved, or all of them if it is dismissed, get deleted.
  final Set<String> _sessionRecordings = {};

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _audioFile = widget.initialAudioFile;
    _audioDurationMs = widget.initialAudioDurationMs;
    _audioWaveform = widget.initialAudioWaveform;
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
    if (!_saved) {
      AnnotationAudioService.deleteAll(_sessionRecordings);
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onRecorded(String fileName, int durationMs, String? waveform) {
    setState(() {
      // Drop an unsaved take that this one replaces.
      if (_audioFile != null && _sessionRecordings.contains(_audioFile)) {
        AnnotationAudioService.delete(_audioFile);
        _sessionRecordings.remove(_audioFile);
      }
      _sessionRecordings.add(fileName);
      _audioFile = fileName;
      _audioDurationMs = durationMs;
      _audioWaveform = waveform;
    });
  }

  void _onAudioRemoved() {
    setState(() {
      if (_audioFile != null && _sessionRecordings.remove(_audioFile)) {
        AnnotationAudioService.delete(_audioFile);
      }
      _audioFile = null;
      _audioDurationMs = null;
      _audioWaveform = null;
    });
  }

  void _onSave() {
    final deltaToMd = DeltaToMarkdown();
    final markdown = deltaToMd.convert(_controller.document.toDelta());
    _saved = true;

    final initialAudio = widget.initialAudioFile;
    if (initialAudio != null && initialAudio != _audioFile) {
      AnnotationAudioService.delete(initialAudio);
    }
    AnnotationAudioService.deleteAll(
      _sessionRecordings.where((f) => f != _audioFile),
    );

    widget.onSave(
      NoteEditorResult(
        markdown: markdown,
        color: _currentColor,
        audioFile: _audioFile,
        audioDurationMs: _audioFile == null ? null : _audioDurationMs,
        audioWaveform: _audioFile == null ? null : _audioWaveform,
      ),
    );
  }

  void _saveAndClose() {
    _onSave();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Breakpoints.isWide(context);
    // Desktop: Ctrl+Enter or Ctrl+S (⌘ on a Mac) saves; Escape cancels, as
    // it closes any panel.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _saveAndClose,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            _saveAndClose,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveAndClose,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _saveAndClose,
      },
      child: _buildPanel(context, isWide),
    );
  }

  Widget _buildPanel(BuildContext context, bool isWide) {
    final colors = context.yomu;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        // Dark mode keeps the reader's menu colour; light mode is an app
        // sheet.
        color: colors.isDark
            ? widget.settings?.menuBackgroundColor ?? colors.surface
            : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: SheetHandle(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              color: colors.tint(0.38),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isWide)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: colors.tint(0.54)),
                      ),
                    ),
                  TextButton(
                    onPressed: _saveAndClose,
                    child: Text(
                      isWide ? 'Save' : 'SAVE',
                      style: TextStyle(
                        color: colors.accent,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: VoiceNoteRecorder(
                fileName: _audioFile,
                durationMs: _audioDurationMs,
                waveform: _audioWaveform,
                onRecorded: _onRecorded,
                onRemoved: _onAudioRemoved,
              ),
            ),
            Divider(height: 1, color: colors.tint(0.10)),
            QuillSimpleToolbar(
              controller: _controller,
              config: QuillSimpleToolbarConfig(
                // A window has room for every tool; a phone scrolls them.
                multiRowsDisplay: isWide,
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
                        color: colors.tint(0.70),
                      ),
                      iconButtonSelectedData: IconButtonData(
                        color: colors.accent,
                        style: IconButton.styleFrom(
                          backgroundColor: colors.tint(0.1),
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
            Divider(height: 1, color: colors.tint(0.10)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: QuillEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: ScrollController(),
                  config: QuillEditorConfig(
                    // Escape closes the editor, like any panel. Quill would
                    // otherwise take it to hide its selection toolbar, so
                    // the editor never closed while it had the cursor. This
                    // is the one hook that runs before Quill's shortcuts.
                    // ignore: experimental_member_use
                    onKeyPressed: (event, node) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        Navigator.maybePop(context);
                        return KeyEventResult.handled;
                      }
                      return null;
                    },
                    padding: EdgeInsets.zero,
                    autoFocus: true,
                    expands: false,
                    placeholder: 'Write something amazing...',
                    customStyles: DefaultStyles(
                      paragraph: DefaultTextBlockStyle(
                        TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          height: 1.6,
                        ),
                        const HorizontalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        null,
                      ),
                      placeHolder: DefaultTextBlockStyle(
                        TextStyle(
                          color: colors.tint(0.24),
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
