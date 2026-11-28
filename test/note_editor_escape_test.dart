import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/models/reader_settings_model.dart';
import 'package:yomu/screens/reading/widgets/highlight_toolbar.dart';
import 'package:yomu/screens/reading/widgets/note_editor.dart';

void main() {
  Future<BuildContext> pumpWindow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext screen;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              screen = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    return screen;
  }

  void openEditor(BuildContext context, ValueChanged<NoteEditorResult> onSave) {
    showHighlightNoteSheet(
      context,
      settings: const ReaderSettings(),
      existing: null,
      onSave: onSave,
    );
  }

  testWidgets('Escape closes the note editor while it has the cursor', (
    tester,
  ) async {
    final screen = await pumpWindow(tester);
    NoteEditorResult? saved;
    openEditor(screen, (r) => saved = r);
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditor), findsOneWidget);
    // The editor takes the cursor as it opens: Quill has the keyboard.
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<QuillEditor>(),
      isNotNull,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditor), findsNothing);
    expect(saved, isNull);
  });

  testWidgets('Cmd+Enter saves and closes the note editor', (tester) async {
    final screen = await pumpWindow(tester);
    NoteEditorResult? saved;
    openEditor(screen, (r) => saved = r);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditor), findsNothing);
    expect(saved, isNotNull);
  });
}
