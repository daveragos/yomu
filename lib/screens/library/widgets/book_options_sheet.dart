import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/book_model.dart';
import '../../../providers/library_provider.dart';
import '../../edit_book_screen.dart';

class BookOptionsSheet extends ConsumerWidget {
  final Book book;

  const BookOptionsSheet({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              book.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: book.isFavorite ? Colors.red : null,
            ),
            title: Text(
              book.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            ),
            onTap: () {
              ref.read(libraryProvider.notifier).toggleBookFavorite(book);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Metadata'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditBookScreen(book: book),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text(
              'Remove Book',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Remove Book'),
                  content: Text(
                    'Are you sure you want to remove "${book.title}"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(libraryProvider.notifier).deleteBook(book.id!);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
