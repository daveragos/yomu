import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/library_provider.dart';

class EmptyLibraryView extends ConsumerWidget {
  final VoidCallback onImportFiles;

  const EmptyLibraryView({super.key, required this.onImportFiles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text('Your library is empty'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(libraryProvider.notifier).scanFolder(),
                icon: const Icon(Icons.folder_open),
                label: const Text('Scan Folder'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onImportFiles,
                icon: const Icon(Icons.add),
                label: const Text('Import Files'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
