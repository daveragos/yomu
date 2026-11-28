import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../utils/share_files.dart';
import '../../../models/book_model.dart';
import '../../../services/annotation_share_service.dart';
import '../../../services/database_service.dart';
import '../../../utils/annotation_order.dart';
import 'share_annotations_dialog.dart';

/// Asks how to share [book] with its notes, builds the file and opens the
/// system share sheet. Used from the reader and from the library.
Future<void> shareBookWithNotes(BuildContext context, Book book) async {
  if (book.id == null) return;
  final db = DatabaseService();
  final service = AnnotationShareService();
  final isPdf = book.filePath.toLowerCase().endsWith('.pdf');

  final highlights = AnnotationOrder.sorted(
    await db.getHighlightsForBook(book.id!),
    isPdf: isPdf,
  );
  final replyCounts = <String, int>{};
  for (final r in await db.getRepliesForBook(book.id!)) {
    replyCounts[r.highlightUid] = (replyCounts[r.highlightUid] ?? 0) + 1;
  }
  final voiceBytes = await service.voiceNoteBytes(book);
  final bookFile = File(book.filePath);
  final bookBytes = await bookFile.exists() ? await bookFile.length() : 0;
  final savedName = await AnnotationShareService.savedSharerName();
  if (!context.mounted) return;

  final options = await ShareAnnotationsDialog.show(
    context,
    bookTitle: book.title,
    isPdf: isPdf,
    highlights: highlights,
    replyCounts: replyCounts,
    voiceBytes: voiceBytes,
    bookBytes: bookBytes,
    initialName: savedName,
  );
  if (options == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  await AnnotationShareService.saveSharerName(options.name);

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(
        content: Text('Preparing book to share…'),
        duration: Duration(minutes: 1),
      ),
    );

  try {
    final file = await service.buildPackage(
      book: book,
      sharerName: options.name,
      includeBook: options.includeBook,
      onlyUids: options.uids,
    );
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    await shareFiles(
      context,
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: AnnotationShareService.mimeTypeFor(file.path),
          ),
        ],
        subject: '${book.title} (with notes from ${options.name})',
        text: 'Open this file with Yomu to read "${book.title}" with my notes.',
      ),
    );
  } catch (e) {
    debugPrint('Failed to share annotated book: $e');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not prepare the book to share.')),
      );
  }
}
