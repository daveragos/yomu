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
              bool deleteHistory = false;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setDialogState) {
                    return AlertDialog(
                      title: const Text('Remove Book'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Are you sure you want to remove "${book.title}" from your library?',
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Remove reading history (minutes, pages, etc.)',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: deleteHistory,
                            onChanged: (val) {
                              setDialogState(() {
                                deleteHistory = val ?? false;
                              });
                            },
                          ),
                        ],
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
                    );
                  },
                ),
              );
              if (confirm == true) {
                ref
                    .read(libraryProvider.notifier)
                    .deleteBook(book.id!, deleteHistory: deleteHistory);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
