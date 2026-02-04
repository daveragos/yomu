import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book_model.dart';
import '../providers/library_provider.dart';
import '../services/database_service.dart';
import '../core/constants.dart';
import 'cover_search_screen.dart';
import '../services/book_service.dart';
import 'package:file_picker/file_picker.dart';

class EditBookScreen extends ConsumerStatefulWidget {
  final Book book;

  const EditBookScreen({super.key, required this.book});

  @override
  ConsumerState<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends ConsumerState<EditBookScreen> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _seriesController;
  late TextEditingController _tagsController;
  String? _newCoverPath;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author);
    _seriesController = TextEditingController(text: widget.book.series ?? '');
    _tagsController = TextEditingController(text: widget.book.tags ?? '');
    _newCoverPath = widget.book.coverPath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _seriesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updatedBook = widget.book.copyWith(
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      series: _seriesController.text.trim().isEmpty
          ? null
          : _seriesController.text.trim(),
      tags: _tagsController.text.trim().isEmpty
          ? null
          : _tagsController.text.trim(),
      coverPath: _newCoverPath ?? widget.book.coverPath,
    );

    await DatabaseService().updateBook(updatedBook);
    ref.read(libraryProvider.notifier).loadBooks();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Metadata updated')));
    }
  }

  Future<void> _pickCoverFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final newPath = await BookService().saveLocalCover(file);
      if (newPath.isNotEmpty) {
        setState(() {
          _newCoverPath = newPath;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Metadata'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(YomuConstants.horizontalPadding),
        child: Column(
          children: [
            _buildTextField('Title', _titleController),
            const SizedBox(height: 20),
            _buildTextField('Author', _authorController),
            const SizedBox(height: 20),
            _buildTextField('Series', _seriesController),
            const SizedBox(height: 20),
            _buildTextField('Tags (comma separated)', _tagsController),
            const SizedBox(height: 40),
            if (_newCoverPath != null && _newCoverPath!.isNotEmpty)
              Column(
                children: [
                  const Text('Book Cover'),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _newCoverPath!.startsWith('http')
                        ? Image.network(
                            _newCoverPath!,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_newCoverPath!),
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCoverFromFile,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Pick from file'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CoverSearchScreen(
                            initialQuery:
                                '${_titleController.text} ${_authorController.text}',
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          _newCoverPath = result;
                        });
                      }
                    },
                    icon: const Icon(Icons.image_search),
                    label: const Text('Search for cover'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
