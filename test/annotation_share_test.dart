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
import 'package:yomu/services/incoming_files.dart';
import 'package:yomu/utils/voice_waveform.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => p.join(root, 'docs');

  // Yomu's data folder on Linux and Windows (FileStorageService.appDataDir).
  @override
  Future<String?> getApplicationSupportPath() async => p.join(root, 'docs');

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

  /// A one-page PDF with a correct cross-reference table.
  String minimalPdf() {
    const objects = [
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>',
    ];
    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(buffer.length);
      buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xref = buffer.length;
    buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF\n',
    );
    return buffer.toString();
  }

  /// A small EPUB-shaped zip.
  Future<String> writeEpub(String path) async {
    final encoder = ZipFileEncoder()..create(path);
    encoder.addArchiveFile(
      ArchiveFile.string('mimetype', 'application/epub+zip'),
    );
    encoder.addArchiveFile(
      ArchiveFile.string('META-INF/container.xml', '<container/>'),
    );
    encoder.addArchiveFile(
      ArchiveFile.string('OEBPS/chapter1.xhtml', '<p>A garden.</p>' * 40),
    );
    await encoder.close();
    return path;
  }

  /// Copies a built file out for checking with other tools, when asked to.
  Future<void> keepSample(File file) async {
    final dir = Platform.environment['YOMU_SHARE_SAMPLES'];
    if (dir != null) await file.copy(p.join(dir, p.basename(file.path)));
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
        audioWaveform: 'AAEC',
        sharedBy: 'Sara',
      );
      final restored = Highlight.fromMap(h.toMap());
      expect(restored.uid, 'abc');
      expect(restored.audioFile, 'a.m4a');
      expect(restored.audioDurationMs, 1200);
      expect(restored.audioWaveform, 'AAEC');
      expect(restored.sharedBy, 'Sara');

      final cleared = restored.copyWith(
        audioFile: null,
        audioDurationMs: null,
        audioWaveform: null,
      );
      expect(cleared.hasAudio, isFalse);
      expect(cleared.audioDurationMs, isNull);
      expect(cleared.audioWaveform, isNull);
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
      final waveform = VoiceWaveform.fromLevels([0.1, 0.9, 0.4, 0.7]);

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
          audioWaveform: waveform,
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
      expect(voiced.audioWaveform, waveform);
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

    test('PDF annotations without the book wait for that exact book', () async {
      final book = await addBook('essay.pdf');
      await db.insertHighlight(
        Highlight(
          bookId: book.id!,
          chapterIndex: 0,
          text: 'Opening line',
          note: 'Great start',
          color: '#2ECC71',
          createdAt: DateTime(2026, 3, 1),
          position: '0:pdf:0:0:12',
          audioFile: await addVoiceNote([1, 2, 3, 4]),
          audioDurationMs: 900,
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
      expect(highlights.single.position, '0:pdf:0:0:12');
      expect(
        await File(
          await AnnotationAudioService.resolve(highlights.single.audioFile!),
        ).readAsBytes(),
        [1, 2, 3, 4],
      );
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

    test('a shared EPUB carries its notes and stays a plain EPUB', () async {
      final dir = await Directory(p.join(root.path, 'hosts')).create();
      final epubPath = await writeEpub(p.join(dir.path, 'garden.epub'));
      final original = await File(epubPath).readAsBytes();
      final book = (await insertBookFrom(epubPath))!;
      final voiceBytes = List.generate(3000, (i) => i % 241);
      await db.insertHighlight(
        Highlight(
          bookId: book.id!,
          chapterIndex: 0,
          text: 'A garden.',
          note: 'Lovely',
          color: '#2ECC71',
          createdAt: DateTime(2026, 4, 1),
          position: '0:exact:0:0.1',
          audioFile: await addVoiceNote(voiceBytes),
          audioDurationMs: 2500,
        ),
      );

      final shared = await service.buildPackage(
        book: book,
        sharerName: 'Dawit',
        includeBook: true,
      );
      await keepSample(shared);
      expect(p.extension(shared.path), '.epub');
      expect(
        AnnotationShareService.mimeTypeFor(shared.path),
        'application/epub+zip',
      );

      // Other apps see the same EPUB: same entries, same contents.
      final bytes = await shared.readAsBytes();
      expect(bytes.sublist(0, original.length), original);
      final asZip = ZipDecoder().decodeBytes(bytes);
      final plain = ZipDecoder().decodeBytes(original);
      expect(asZip.files.map((f) => f.name), plain.files.map((f) => f.name));
      expect(
        asZip.findFile('OEBPS/chapter1.xhtml')!.content,
        plain.findFile('OEBPS/chapter1.xhtml')!.content,
      );

      expect(await AnnotationShareService.looksLikePackage(shared.path), true);
      expect((await IncomingFiles.sort([shared.path])).packages, [shared.path]);
      final manifest = await service.readManifest(shared.path);
      expect(manifest.voiceNoteCount, 1);
      expect(manifest.bookEntry, isNull);

      // A reader without the book gets the exact original back.
      await db.hardDeleteBook(book.id!);
      final result = await service.importPackage(
        shared.path,
        addBookToLibrary: insertBookFrom,
      );
      expect(result.added, 1);
      expect(await File(result.book!.filePath).readAsBytes(), original);
      final received = (await db.getHighlightsForBook(result.book!.id!)).single;
      expect(received.sharedBy, 'Dawit');
      expect(received.note, 'Lovely');
      expect(
        await File(
          await AnnotationAudioService.resolve(received.audioFile!),
        ).readAsBytes(),
        voiceBytes,
      );
    });

    test('a shared PDF carries its notes and stays a plain PDF', () async {
      final dir = await Directory(
        p.join(root.path, 'pdf_hosts'),
      ).create(recursive: true);
      final pdfPath = p.join(dir.path, 'paper.pdf');
      final pdfText = minimalPdf();
      await File(pdfPath).writeAsString(pdfText);
      final original = await File(pdfPath).readAsBytes();
      final book = (await insertBookFrom(pdfPath))!;
      await db.insertHighlight(
        Highlight(
          bookId: book.id!,
          chapterIndex: 0,
          text: 'Abstract',
          color: '#3498DB',
          createdAt: DateTime(2026, 4, 2),
          position: '0:pdf:0:0:8',
        ),
      );

      final shared = await service.buildPackage(
        book: book,
        sharerName: 'Sara',
        includeBook: true,
      );
      await keepSample(shared);
      expect(p.extension(shared.path), '.pdf');
      expect(AnnotationShareService.mimeTypeFor(shared.path), 'application/pdf');

      // The original bytes come first, and the file still ends by pointing
      // PDF readers at the original cross-reference table.
      final bytes = await shared.readAsBytes();
      expect(bytes.sublist(0, original.length), original);
      final xref = RegExp(r'startxref\n(\d+)').firstMatch(pdfText)!.group(1);
      expect(
        latin1.decode(bytes.sublist(bytes.length - 40)),
        endsWith('startxref\n$xref\n%%EOF\n'),
      );

      // Tampering with the book is caught.
      final tampered = File(p.join(dir.path, 'tampered.pdf'));
      await tampered.writeAsBytes([...bytes]..[12] ^= 0x20);
      await db.hardDeleteBook(book.id!);
      await expectLater(
        service.importPackage(
          tampered.path,
          addBookToLibrary: (_) async => fail('must not add a changed book'),
        ),
        throwsFormatException,
      );

      final result = await service.importPackage(
        shared.path,
        addBookToLibrary: insertBookFrom,
      );
      expect(await File(result.book!.filePath).readAsBytes(), original);
      final received = (await db.getHighlightsForBook(result.book!.id!)).single;
      expect(received.position, '0:pdf:0:0:8');
      expect(received.sharedBy, 'Sara');
    });

    test('picked and shared files are sorted by what Yomu can open', () async {
      final dir = await Directory(p.join(root.path, 'incoming')).create();
      Future<String> touch(String name) async {
        final file = File(p.join(dir.path, name));
        await file.writeAsBytes([1, 2, 3]);
        return file.path;
      }

      final book = await addBook('incoming.epub');
      final package = await service.buildPackage(
        book: book,
        sharerName: 'Dawit',
        includeBook: false,
      );
      // Some apps hand files over under a made-up name such as FILE_123.bin.
      final renamed = await File(
        package.path,
      ).copy(p.join(dir.path, 'FILE_123.bin'));

      final sorted = await IncomingFiles.sort([
        await touch('a.epub'),
        await touch('B.PDF'),
        package.path,
        renamed.path,
        await touch('notes.txt'),
        await touch('other.bin'),
      ]);
      expect(sorted.books.map(p.basename), ['a.epub', 'B.PDF']);
      expect(sorted.packages, [package.path, renamed.path]);
      expect(sorted.unsupported.map(p.basename), ['notes.txt', 'other.bin']);

      const skippedOnly = IncomingImportSummary(
        books: [],
        packages: [],
        failures: [],
        skipped: 2,
      );
      expect(skippedOnly.bookToOpen, isNull);
      expect(skippedOnly.messages().single, startsWith('Skipped 2 files'));

      // A book that fails to read is named, not called "not a book".
      const unreadable = IncomingImportSummary(
        books: [],
        packages: [],
        failures: [],
        skipped: 1,
        unreadable: ['History.epub'],
      );
      expect(unreadable.messages(), [
        startsWith("Couldn't open \"History.epub\""),
        startsWith("Yomu can't open that file"),
      ]);
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
