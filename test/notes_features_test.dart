import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yomu/models/annotation_reply_model.dart';
import 'package:yomu/models/book_model.dart';
import 'package:yomu/models/highlight_model.dart';
import 'package:yomu/services/annotation_audio_service.dart';
import 'package:yomu/services/annotation_share_service.dart';
import 'package:yomu/services/database_service.dart';
import 'package:yomu/services/incoming_files.dart';
import 'package:yomu/utils/annotation_order.dart';
import 'package:yomu/utils/epub_text_match.dart';
import 'package:yomu/utils/pdf_highlight_anchor.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => p.join(root, 'docs');

  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');
}

void main() {
  late Directory root;
  final db = DatabaseService();
  final service = AnnotationShareService();

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('yomu_notes_test');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactoryFfi.setDatabasesPath(p.join(root.path, 'db'));
  });

  tearDownAll(() async {
    await root.delete(recursive: true);
  });

  Future<Book> addBook(String fileName, {String title = 'Garden'}) async {
    final dir = await Directory(p.join(root.path, 'books')).create(
      recursive: true,
    );
    final file = File(p.join(dir.path, fileName));
    final random = Random();
    await file.writeAsBytes(List.generate(4096, (_) => random.nextInt(256)));
    final book = Book(
      title: title,
      author: 'Author',
      coverPath: '',
      filePath: file.path,
      addedAt: DateTime(2026, 1, 1),
      contentHash: md5.convert(await file.readAsBytes()).toString(),
    );
    final id = await db.insertBook(book);
    return book.copyWith(id: id);
  }

  Highlight note(int bookId, String uid, {bool private = false}) => Highlight(
    bookId: bookId,
    chapterIndex: 1,
    text: 'Passage $uid',
    note: 'Thoughts on $uid',
    color: '#F1C40F',
    createdAt: DateTime(2026, 5, 1),
    position: '1:ratio:0.5',
    uid: uid,
    isPrivate: private,
  );

  test('private flag and text anchoring survive the database', () async {
    final book = await addBook('a.epub');
    await db.insertHighlight(
      note(book.id!, 'p1', private: true).copyWith(
        anchorState: Highlight.anchorByText,
      ),
    );
    final saved = (await db.getHighlightsForBook(book.id!)).single;
    expect(saved.isPrivate, isTrue);
    expect(saved.needsPlacing, isTrue);
    final placed = saved.copyWith(anchorState: null, isPrivate: false);
    await db.updateHighlight(placed);
    final reloaded = (await db.getHighlightsForBook(book.id!)).single;
    expect(reloaded.isPrivate, isFalse);
    expect(reloaded.anchorState, isNull);
  });

  test('deleting a note deletes its replies and their voice notes', () async {
    final book = await addBook('b.epub');
    final id = await db.insertHighlight(note(book.id!, 'n1'));
    final audio = AnnotationAudioService.newFileName();
    final audioPath = await AnnotationAudioService.resolve(audio);
    await File(audioPath).writeAsBytes([1, 2, 3]);
    await db.insertReply(
      AnnotationReply(
        bookId: book.id!,
        highlightUid: 'n1',
        uid: 'r1',
        text: 'Agreed',
        audioFile: audio,
        createdAt: DateTime(2026, 5, 2),
      ),
    );
    expect(await db.getRepliesForBook(book.id!), hasLength(1));
    await db.deleteHighlight(id);
    expect(await db.getRepliesForBook(book.id!), isEmpty);
    expect(await File(audioPath).exists(), isFalse);
  });

  test('shares leave out private notes and unpicked ones, and carry replies '
      'both ways', () async {
    final book = await addBook('c.epub');
    await db.insertHighlight(note(book.id!, 'keep'));
    await db.insertHighlight(note(book.id!, 'skip'));
    await db.insertHighlight(note(book.id!, 'secret', private: true));
    await db.insertReply(
      AnnotationReply(
        bookId: book.id!,
        highlightUid: 'keep',
        uid: 'my-reply',
        text: 'Mine',
        createdAt: DateTime(2026, 5, 3),
      ),
    );

    final shared = await service.buildPackage(
      book: book,
      sharerName: 'Dawit',
      includeBook: false,
      onlyUids: {'keep', 'secret'},
    );
    expect(p.basename(shared.path), 'Garden (notes by Dawit).yomu');
    final manifest = await service.readManifest(shared.path);
    expect(manifest.annotations.map((a) => a.uid), ['keep']);
    expect(manifest.replies.single.author, 'Dawit');

    // A friend with the same book gets the note and the reply...
    await db.hardDeleteBook(book.id!);
    final friendBook = (await db.insertBook(book.copyWith(id: null)));
    final friend = book.copyWith(id: friendBook);
    final result = await service.importPackage(
      shared.path,
      addBookToLibrary: (_) async => fail('the friend has the book'),
    );
    expect(result.added, 1);
    expect(result.repliesAdded, 1);
    expect(describeImport(result), contains('1 new note'));
    final replies = await db.getRepliesForBook(friend.id!);
    expect(replies.single.author, 'Dawit');

    // ...answers it, and shares back.
    await db.insertReply(
      AnnotationReply(
        bookId: friend.id!,
        highlightUid: 'keep',
        uid: 'friend-reply',
        text: 'Mine too',
        createdAt: DateTime(2026, 5, 4),
      ),
    );
    final back = await service.buildPackage(
      book: friend,
      sharerName: 'Sara',
      includeBook: false,
    );
    final backManifest = await service.readManifest(back.path);
    expect(
      backManifest.replies.map((r) => r.author),
      containsAll(['Dawit', 'Sara']),
    );

    // Opening it again on the friend's side changes nothing of theirs.
    final again = await service.importPackage(
      back.path,
      addBookToLibrary: (_) async => fail('has the book'),
    );
    expect(again.added + again.repliesAdded, 0);
    final mine = (await db.getRepliesForBook(friend.id!)).firstWhere(
      (r) => r.uid == 'friend-reply',
    );
    expect(mine.isMine, isTrue);
  });

  test('notes for another copy wait, then go on it by their text', () async {
    final original = await addBook('d.epub', title: 'The Sea');
    await db.insertHighlight(note(original.id!, 'sea1'));
    final package = await service.buildPackage(
      book: original,
      sharerName: 'Abebe',
      includeBook: false,
    );
    await db.hardDeleteBook(original.id!);

    // The reader has a different copy (different bytes) of "The Sea".
    final mine = await addBook('mine.epub', title: 'the sea');
    final result = await service.importPackage(
      package.path,
      addBookToLibrary: (_) async => fail('no book in this package'),
    );
    expect(result.isPending, isTrue);
    expect(result.similarBook?.id, mine.id);

    final pending = await service.listPending();
    expect(pending.single.manifest.sharedBy, 'Abebe');
    expect(pending.single.similarBook?.id, mine.id);

    final placed = await service.placePendingOn(pending.single.path, mine);
    expect(placed.added, 1);
    final h = (await db.getHighlightsForBook(mine.id!)).single;
    expect(h.needsPlacing, isTrue);
    expect(h.sharedBy, 'Abebe');
    expect(await service.listPending(), isEmpty);
  });

  test('passages are found in the nearest chapter, nearest occurrence', () {
    final chapters = [
      '<body><p>The tide comes in.</p></body>',
      '<body><p>Nothing here.</p></body>',
      '<body><p>The <b>tide</b>\n comes in. Later: the tide comes in.</p></body>',
    ];
    final found = findInChapters(
      chapters,
      'the tide comes in',
      near: 2,
      nearRatio: 0.9,
    )!;
    expect(found.chapter, 2);
    expect(found.occurrence, 1);
    expect(found.position, startsWith('2:exact:1:'));

    final elsewhere = findInChapters(chapters, 'tide comes in', near: 1)!;
    expect(elsewhere.chapter, isIn([0, 2]));
    expect(findInChapters(chapters, 'no such passage'), isNull);
  });

  test('pdf passages are found by text', () {
    const page = 'One line here.\nAnother line there.';
    expect(PdfHighlightAnchor.find(page, 'line there'), (start: 23, end: 33));
    expect(PdfHighlightAnchor.find(page, 'missing'), isNull);
  });

  test('reading order and places', () {
    Highlight h(int chapter, String position, [String? title]) => Highlight(
      bookId: 1,
      chapterIndex: chapter,
      text: 't',
      color: '#F1C40F',
      createdAt: DateTime(2026),
      position: position,
    );
    final epub = AnnotationOrder.sorted([
      h(2, '2:ratio:0.1'),
      h(1, '1:exact:0:0.8'),
      h(1, '1:ratio:0.2'),
    ], isPdf: false);
    expect(epub.map((e) => e.position), [
      '1:ratio:0.2',
      '1:exact:0:0.8',
      '2:ratio:0.1',
    ]);
    final pdf = AnnotationOrder.sorted([
      h(0, '0:pdf:50:0:60'),
      h(0, '0:pdf:5:0:9'),
    ], isPdf: true);
    expect(pdf.first.position, '0:pdf:5:0:9');
    expect(AnnotationOrder.location(h(4, ''), isPdf: true), 'p. 5');
    expect(
      AnnotationOrder.location(h(1, ''), isPdf: false, chapterTitles: [
        'One',
        'Two',
      ]),
      'Two',
    );
    expect(AnnotationOrder.location(h(7, ''), isPdf: false), 'Chapter 8');
  });

  test('file names name the sharer and stay safe', () {
    expect(
      AnnotationShareService.shareFileStem('War & Peace: Vol/1', 'Dawit'),
      'War Peace Vol 1 (notes by Dawit)',
    );
    expect(AnnotationShareService.shareFileStem('', ''), 'Book');
    expect(
      AnnotationShareService.shareFileStem('ፍቅር እስከ መቃብር', 'ዳዊት'),
      'ፍቅር እስከ መቃብር (notes by ዳዊት)',
    );
  });
}
