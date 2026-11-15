import 'package:path/path.dart' as p;
import '../models/book_model.dart';
import 'annotation_share_service.dart';

/// Files picked in the app or opened with Yomu, sorted by what Yomu can do
/// with them.
class IncomingFiles {
  const IncomingFiles({
    required this.books,
    required this.packages,
    required this.unsupported,
  });

  /// EPUB and PDF files.
  final List<String> books;

  /// Books shared with annotations: an EPUB or PDF with notes appended, a
  /// `.yomu` file, or either of those under another name.
  final List<String> packages;

  final List<String> unsupported;

  static Future<IncomingFiles> sort(Iterable<String> paths) async {
    final books = <String>[];
    final packages = <String>[];
    final unsupported = <String>[];
    for (final path in paths) {
      final extension = p.extension(path).toLowerCase();
      // Checked first: a shared EPUB or PDF can carry notes.
      if (await AnnotationShareService.looksLikePackage(path)) {
        packages.add(path);
      } else if (extension == '.epub' || extension == '.pdf') {
        books.add(path);
      } else {
        unsupported.add(path);
      }
    }
    return IncomingFiles(
      books: books,
      packages: packages,
      unsupported: unsupported,
    );
  }
}

/// "From Abebe in “Title”: 3 new notes, 2 updated, 1 new reply."
String describeImport(SharedImportResult result) {
  final from = result.manifest.sharedBy ?? 'another reader';
  final title = result.manifest.title;
  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final parts = [
    if (result.added > 0) count(result.added, 'new note', 'new notes'),
    if (result.updated > 0) '${result.updated} updated',
    if (result.repliesAdded > 0)
      count(result.repliesAdded, 'new reply', 'new replies'),
    if (result.repliesUpdated > 0)
      count(result.repliesUpdated, 'reply updated', 'replies updated'),
  ];
  if (parts.isEmpty) return 'Opened "$title" from $from. Nothing new.';
  return 'From $from in "$title": ${parts.join(', ')}.';
}

/// What importing picked or shared files did.
class IncomingImportSummary {
  const IncomingImportSummary({
    required this.books,
    required this.packages,
    required this.failures,
    required this.skipped,
  });

  /// Books from plain EPUB/PDF files, new or already in the library.
  final List<Book> books;

  /// Books shared with annotations.
  final List<SharedImportResult> packages;

  /// Why shared packages could not be opened.
  final List<String> failures;

  /// Files Yomu can't open: not a book or package, or unreadable.
  final int skipped;

  /// The book to open: the first shared one, else the first plain one.
  Book? get bookToOpen =>
      packages.map((r) => r.book).nonNulls.firstOrNull ?? books.firstOrNull;

  /// Lines for a snackbar about shared packages and skipped files.
  List<String> messages() {
    final lines = <String>[];
    for (final result in packages) {
      final from = result.manifest.sharedBy ?? 'another reader';
      final title = result.manifest.title;
      if (result.isPending) {
        lines.add(
          'Saved notes from $from for "$title". '
          'They will appear when you add that exact book.',
        );
        continue;
      }
      lines.add(describeImport(result));
    }
    lines.addAll(failures);
    if (skipped == 1) {
      lines.add("Yomu can't open that file. It isn't a book or a Yomu file.");
    } else if (skipped > 1) {
      lines.add(
        "Skipped $skipped files Yomu can't open. "
        "They aren't books or Yomu files.",
      );
    }
    return lines;
  }
}
