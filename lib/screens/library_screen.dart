import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../components/book_card.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final books = [
      {
        'title': 'Project Hail Mary',
        'author': 'Andy Weir',
        'progress': 0.65,
        'url':
            'https://m.media-amazon.com/images/I/81vdYEn9XPL._AC_UF1000,1000_QL80_.jpg',
      },
      {
        'title': 'The Midnight Library',
        'author': 'Matt Haig',
        'progress': 0.32,
        'url':
            'https://m.media-amazon.com/images/I/71K8iVRYLBL._AC_UF1000,1000_QL80_.jpg',
      },
      {
        'title': 'Hyperion',
        'author': 'Dan Simmons',
        'progress': 0.12,
        'url': 'https://m.media-amazon.com/images/I/51pM1jA0QXL.jpg',
      },
      {
        'title': 'Dune',
        'author': 'Frank Herbert',
        'progress': 1.0,
        'url':
            'https://m.media-amazon.com/images/I/81AAb8-m8XL._AC_UF1000,1000_QL80_.jpg',
      },
      {
        'title': 'Foundation',
        'author': 'Isaac Asimov',
        'progress': 0.0,
        'url':
            'https://m.media-amazon.com/images/I/71626m4CIdL._AC_UF1000,1000_QL80_.jpg',
      },
      {
        'title': 'The Martian',
        'author': 'Andy Weir',
        'progress': 1.0,
        'url':
            'https://m.media-amazon.com/images/I/818Z3M6WvEL._AC_UF1000,1000_QL80_.jpg',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(YomuConstants.horizontalPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return BookCard(
            title: book['title'] as String,
            author: book['author'] as String,
            coverUrl: book['url'] as String,
            progress: book['progress'] as double,
          );
        },
      ),
    );
  }
}
