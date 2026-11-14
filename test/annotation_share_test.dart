import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yomu/models/book_model.dart';
import 'package:yomu/models/highlight_model.dart';
import 'package:yomu/services/annotation_audio_service.dart';
import 'package:yomu/services/annotation_share_service.dart';
import 'package:yomu/services/database_service.dart';

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
    root = await Directory.systemTemp.createTemp('yomu_share_test');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactoryFfi.setDatabasesPath(p.join(root.path, 'db'));
  });

  tearDownAll(() async {
    await root.delete(recursive: true);
  });

  /// Writes a fake book with unique bytes and adds it to the library.
  Future<Book> addBook(String fileName) async {
    final dir = Directory(p.join(root.path, 'books'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
    final random = Random();
    await file.writeAsBytes(List.generate(4096, (_) => random.nextInt(256)));
    final book = Book(
      title: p.basenameWithoutExtension(fileName),
      author: 'Author',
      coverPath: '',
      filePath: file.path,
      addedAt: DateTime(2026, 1, 1),
      contentHash: md5.convert(await file.readAsBytes()).toString(),
    );
    final id = await db.insertBook(book);
    return book.copyWith(id: id);
  }

  Future<String> addVoiceNote(List<int> bytes) async {
    final name = AnnotationAudioService.newFileName();
    await File(await AnnotationAudioService.resolve(name)).writeAsBytes(bytes);
    return name;
  }

  Future<Book?> insertBookFrom(String path) async {
    final book = Book(
      title: 'Imported',
      author: 'Author',
      coverPath: '',
      filePath: path,
      addedAt: DateTime(2026, 1, 2),
      contentHash: await AnnotationShareService.fileMd5(File(path)),
    );
    final id = await db.insertBook(book);
    return book.copyWith(id: id);
  }

  group('Highlight', () {
    test('round-trips sharing fields and can clear its voice note', () {
      final h = Highlight(
        bookId: 1,
        chapterIndex: 2,
        text: 'text',
        color: '#F1C40F',
        createdAt: DateTime(2026, 1, 1),
        position: '2:exact:0:0.5',
        uid: 'abc',
        audioFile: 'a.m4a',
        audioDurationMs: 1200,
        sharedBy: 'Sara',
      );
      final restored = Highlight.fromMap(h.toMap());
      expect(restored.uid, 'abc');
      expect(restored.audioFile, 'a.m4a');
      expect(restored.audioDurationMs, 1200);
      expect(restored.sharedBy, 'Sara');

      final cleared = restored.copyWith(audioFile: null, audioDurationMs: null);
      expect(cleared.hasAudio, isFalse);
      expect(cleared.audioDurationMs, isNull);
      expect(cleared.sharedBy, 'Sara');
    });
  });

  group('AnnotationPackageManifest', () {
    Map<String, dynamic> validJson() => {
      'format': AnnotationShareService.formatId,
      'version': 1,
      'book': {
        'contentHash': 'a' * 32,
        'title': 'T',
        'author': 'A',
        'fileName': 'b.epub',
        'entry': 'book/b.epub',
      },
      'sharedBy': 'Dawit',
      'sharedAt': '2026-11-14T00:00:00.000',
      'annotations': [
        {
          'uid': 'u1',
          'chapterIndex': 0,
          'text': 'hello',
          'color': '#F1C40F',
          'createdAt': '2026-11-14T00:00:00.000',
          'position': '0:ratio:0.1',
          'audio': '../../evil.m4a',
        },
      ],
    };

    test('ignores entries outside the audio and book folders', () {
      final json = validJson();
      (json['book'] as Map)['entry'] = '../book.epub';
      final m = AnnotationPackageManifest.fromJson(json);
      expect(m.bookEntry, isNull);
      expect(m.annotations.single.audioEntry, isNull);
    });

    test('rejects other formats, newer versions and missing hashes', () {
      expect(
        () => AnnotationPackageManifest.fromJson(validJson()..['format'] = 'x'),
        throwsFormatException,
      );
      expect(
        () => AnnotationPackageManifest.fromJson(validJson()..['version'] = 99),
        throwsFormatException,
      );
      final noHash = validJson();
      (noHash['book'] as Map)['contentHash'] = 'not-a-hash';
      expect(
        () => AnnotationPackageManifest.fromJson(noHash),
        throwsFormatException,
      );
    });
  });

  group('sharing a book with annotations', () {
    test('recipient gets the exact book with notes and voice notes', () async {
      final book = await addBook('novel.epub');
      final originalBookBytes = await File(book.filePath).readAsBytes();
      final voiceBytes = List.generate(2000, (i) => i % 251);

      await db.insertHighlight(
        Highlight(
          bookId: book.id!,
          chapterIndex: 3,
          text: 'A line worth hearing',
          note: '**Listen** to this',
          color: '#E74C3C',
          createdAt: DateTime(2026, 2, 1),
          position: '3:exact:0:0.4',
          audioFile: await addVoiceNote(voiceBytes),
          audioDurationMs: 4200,
        ),
      );
      await db.insertHighlight(
        Highlight(
          bookId: book.id!,
          chapterIndex: 5,
          text: 'Passed along from a friend',
          color: '#3498DB',
          createdAt: DateTime(2026, 2, 2),
          position: '5:ratio:0.9',
          sharedBy: 'Sara',
        ),
      );

      final package = await service.buildPackage(
        book: book,
        sharerName: 'Dawit',
        includeBook: true,
      );
      expect(p.extension(package.path), AnnotationShareService.fileExtension);
      expect(await AnnotationShareService.looksLikePackage(package.path), true);

      final manifest = await service.readManifest(package.path);
      expect(manifest.contentHash, book.contentHash);
      expect(manifest.annotations, hasLength(2));
      expect(manifest.voiceNoteCount, 1);
      expect(
        manifest.annotations.map((a) => a.author),
        containsAll(['Dawit', 'Sara']),
      );

      // The sharer opening their own package keeps their own annotations.
      final again = await service.importPackage(
        package.path,
        addBookToLibrary: (_) async => fail('book is already in the library'),
      );
      expect(again.book?.id, book.id);
      expect(again.added, 0);
      expect(await db.getHighlightsForBook(book.id!), hasLength(2));

      // A reader who does not have the book yet.
      await db.hardDeleteBook(book.id!);
      final result = await service.importPackage(
        package.path,
        addBookToLibrary: insertBookFrom,
      );
      expect(result.isPending, isFalse);
      expect(result.added, 2);
      expect(result.book!.contentHash, book.contentHash);
      expect(result.book!.filePath, isNot(book.filePath));
      expect(await File(result.book!.filePath).readAsBytes(), originalBookBytes);

      final received = await db.getHighlightsForBook(result.book!.id!);
      final voiced = received.singleWhere((h) => h.hasAudio);
      expect(voiced.sharedBy, 'Dawit');
      expect(voiced.note, '**Listen** to this');
      expect(voiced.position, '3:exact:0:0.4');
      expect(voiced.audioDurationMs, 4200);
      expect(
        await File(
          await AnnotationAudioService.resolve(voiced.audioFile!),
        ).readAsBytes(),
        voiceBytes,
      );
      expect(received.singleWhere((h) => !h.hasAudio).sharedBy, 'Sara');

      // Opening the same package twice does not duplicate annotations.
      final repeat = await service.importPackage(
        package.path,
        addBookToLibrary: (_) async => fail('book is already in the library'),
      );
      expect(repeat.added, 0);
      expect(repeat.updated, 2);
      expect(await db.getHighlightsForBook(result.book!.id!), hasLength(2));
    });

    test('annotations without the book wait for that exact book', () async {
      final book = await addBook('essay.pdf');
      await db.insertHighlight(
        Highlight(
          bookId: book.id!,
          chapterIndex: 0,
          text: 'Opening line',
          note: 'Great start',
          color: '#2ECC71',
          createdAt: DateTime(2026, 3, 1),
          position: '0:ratio:0.0',
        ),
      );
      final package = await service.buildPackage(
        book: book,
        sharerName: 'Dawit',
        includeBook: false,
      );
      await db.hardDeleteBook(book.id!);

      final result = await service.importPackage(
        package.path,
        addBookToLibrary: (_) async => fail('package has no book file'),
      );
      expect(result.isPending, isTrue);

      // A different book does not pick them up.
      final other = await addBook('other.pdf');
      expect(await service.applyPendingFor(other), isEmpty);

      // Adding the exact book does.
      final readded = await insertBookFrom(book.filePath);
      final applied = await service.applyPendingFor(readded!);
      expect(applied.single.added, 1);
      final highlights = await db.getHighlightsForBook(readded.id!);
      expect(highlights.single.note, 'Great start');
      expect(highlights.single.sharedBy, 'Dawit');
      expect(await service.applyPendingFor(readded), isEmpty);
    });

    test('rejects a package whose book does not match its hash', () async {
      final path = p.join(root.path, 'tampered.yomu');
      final encoder = ZipFileEncoder()..create(path);
      encoder.addArchiveFile(
        ArchiveFile.string(
          AnnotationShareService.manifestEntry,
          jsonEncode({
            'format': AnnotationShareService.formatId,
            'version': 1,
            'book': {
              'contentHash': 'b' * 32,
              'title': 'Tampered',
              'author': 'X',
              'fileName': 'tampered.epub',
              'entry': 'book/tampered.epub',
            },
            'sharedBy': 'Mallory',
            'annotations': [],
          }),
        ),
      );
      encoder.addArchiveFile(
        ArchiveFile.bytes('book/tampered.epub', utf8.encode('not that book')),
      );
      await encoder.close();

      await expectLater(
        service.importPackage(
          path,
          addBookToLibrary: (_) async => fail('must not add a mismatched book'),
        ),
        throwsFormatException,
      );
    });

    test('plain books are not mistaken for packages', () async {
      final epub = File(p.join(root.path, 'plain.epub'));
      await epub.writeAsString('x');
      final random = File(p.join(root.path, 'download.bin'));
      await random.writeAsString('not a zip');
      expect(await AnnotationShareService.looksLikePackage(epub.path), isFalse);
      expect(
        await AnnotationShareService.looksLikePackage(random.path),
        isFalse,
      );
    });
  });
}
