import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal EPUB 2 whose chapter, image and stylesheet sit at the given
/// paths (relative to the OPF in `OPS/`).
Uint8List buildEpub({
  required String chapterHref,
  required String imageHref,
  required String styleHref,
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<?xml version="1.0"?>'
            '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="OPS/content.opf" '
            'media-type="application/oebps-package+xml"/></rootfiles>'
            '</container>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OPS/content.opf',
        '<?xml version="1.0"?>'
            '<package xmlns="http://www.idpf.org/2007/opf" version="2.0" '
            'unique-identifier="id">'
            '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
            '<dc:title>Names</dc:title><dc:identifier id="id">x</dc:identifier>'
            '</metadata>'
            '<manifest>'
            '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
            '<item id="ch" href="$chapterHref" media-type="application/xhtml+xml"/>'
            '<item id="img" href="$imageHref" media-type="image/png"/>'
            '<item id="css" href="$styleHref" media-type="text/css"/>'
            '</manifest>'
            '<spine toc="ncx"><itemref idref="ch"/></spine>'
            '</package>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OPS/toc.ncx',
        '<?xml version="1.0"?>'
            '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">'
            '<head/><docTitle><text>Names</text></docTitle><navMap>'
            '<navPoint id="p1" playOrder="1"><navLabel><text>One</text></navLabel>'
            '<content src="$chapterHref"/></navPoint>'
            '</navMap></ncx>',
      ),
    );

  String stored(String href) =>
      Uri.decodeFull(Uri.parse('OPS/$href').normalizePath().path);
  archive
    ..addFile(
      ArchiveFile.string(
        stored(chapterHref),
        '<html><body><p>Chapter one.</p></body></html>',
      ),
    )
    ..addFile(ArchiveFile.bytes(stored(imageHref), Uint8List(16)))
    ..addFile(ArchiveFile.string(stored(styleHref), 'p { margin: 0 }'));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('opens a book whose files have spaces in their names', () async {
    final book = await EpubReader.readBook(
      buildEpub(
        chapterHref: 'text/Chapter 1.xhtml',
        imageHref: 'images/Screen shot 2011-11-12 at 21.41.10.png',
        styleHref: 'styles/main style.css',
      ),
    );
    expect(book.Chapters!.single.HtmlContent, contains('Chapter one.'));
    expect(
      book.Content!.Images!.keys,
      contains('images/Screen shot 2011-11-12 at 21.41.10.png'),
    );
  });

  test('opens a book with non-ASCII image and style names', () async {
    // The manifest percent-encodes them; the archive stores them as is.
    final imageHref = Uri.encodeFull('images/ምስል 写真.png');
    final book = await EpubReader.readBook(
      buildEpub(
        chapterHref: 'chapter.xhtml',
        imageHref: imageHref,
        styleHref: Uri.encodeFull('styles/ቅጥ.css'),
      ),
    );
    expect(book.Content!.Images![imageHref]!.Content, hasLength(16));
  });

  test('still resolves paths that step out of the OPF folder', () async {
    final book = await EpubReader.readBook(
      buildEpub(
        chapterHref: 'text/../text/one.xhtml',
        imageHref: '../images/cover.png',
        styleHref: './styles/main.css',
      ),
    );
    expect(book.Chapters!.single.HtmlContent, contains('Chapter one.'));
    expect(book.Content!.Images!.keys, contains('../images/cover.png'));
  });
}
