import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book_model.dart';

/// A book's cover, from the app's assets or a file, falling back to the
/// Yomu icon when the image is missing.
class BookCoverImage extends StatelessWidget {
  final Book book;
  final BoxFit fit;

  const BookCoverImage({super.key, required this.book, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/icon.png',
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          ),
        );

    return book.coverPath.startsWith('assets')
        ? Image.asset(
            book.coverPath,
            fit: fit,
            alignment: Alignment.topCenter,
            errorBuilder: fallback,
          )
        : Image.file(
            File(book.coverPath),
            fit: fit,
            alignment: Alignment.topCenter,
            errorBuilder: fallback,
          );
  }
}
