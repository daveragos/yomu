import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book_model.dart';
import '../providers/library_provider.dart';
import '../core/constants.dart';
import 'google_image_search_screen.dart';
import '../services/book_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

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
  late List<AudioTrack> _audioTracks;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author);
    _seriesController = TextEditingController(text: widget.book.series ?? '');
    _tagsController = TextEditingController(text: widget.book.tags ?? '');
    _newCoverPath = widget.book.coverPath;
    _audioTracks = List.from(widget.book.audioTracks);

    // If there's an old audioPath but no tracks, add it as the first track
    if (widget.book.audioPath != null &&
        widget.book.audioPath!.isNotEmpty &&
        _audioTracks.isEmpty) {
      _audioTracks.add(
        AudioTrack(
          path: widget.book.audioPath!,
          title: p.basename(widget.book.audioPath!),
        ),
      );
    }
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
      audioTracks: _audioTracks,
      // If we have tracks, we can optionally clear the single audioPath or keep it as the first one
      audioPath: _audioTracks.isNotEmpty ? _audioTracks.first.path : null,
    );

    await ref.read(libraryProvider.notifier).updateBook(updatedBook);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Book updated')));
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

  Future<void> _pickAudioTracks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      int duplicatesCount = 0;
      setState(() {
        for (final path in result.paths) {
          if (path != null) {
            // Avoid duplicates
            if (!_audioTracks.any((t) => t.path == path)) {
              _audioTracks.add(AudioTrack(path: path, title: p.basename(path)));
            } else {
              duplicatesCount++;
            }
          }
        }
      });

      if (duplicatesCount > 0 && mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                duplicatesCount == result.paths.length
                    ? 'All selected files are already in this book.'
                    : 'Skipped $duplicatesCount duplicate files.',
              ),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Book'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(YomuConstants.horizontalPadding),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final track = _audioTracks.removeAt(oldIndex);
            _audioTracks.insert(newIndex, track);
          });
        },
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('Title', _titleController),
            const SizedBox(height: 20),
            _buildTextField('Author', _authorController),
            const SizedBox(height: 20),
            _buildTextField('Series', _seriesController),
            const SizedBox(height: 20),
            _buildTextField('Tags (comma separated)', _tagsController),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Audiobook Parts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_audioTracks.isNotEmpty)
                  Text(
                    '${_audioTracks.length} items',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_audioTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'No audio parts attached.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
          ],
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickAudioTracks,
              icon: const Icon(Icons.add),
              label: const Text('Add Parts'),
            ),
            const SizedBox(height: 40),
            const Text(
              'Book Cover',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_newCoverPath != null && _newCoverPath!.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _newCoverPath!.startsWith('http')
                      ? Image.network(
                          _newCoverPath!,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Image.asset(
                              'assets/icon.png',
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : Image.file(
                          File(_newCoverPath!),
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Image.asset(
                              'assets/icon.png',
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                ),
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
                      final selectedUrl = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GoogleImageSearchScreen(
                            query:
                                '${_titleController.text} ${_authorController.text}',
                          ),
                        ),
                      );
                      if (selectedUrl != null && mounted) {
                        final newPath = await BookService().downloadCover(
                          selectedUrl,
                        );
                        if (newPath.isNotEmpty && mounted) {
                          setState(() {
                            _newCoverPath = newPath;
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.image_search),
                    label: const Text('Search online'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
        itemCount: _audioTracks.length,
        itemBuilder: (context, index) {
          final track = _audioTracks[index];
          return Card(
            key: ValueKey(track.path + index.toString()),
            color: YomuConstants.surface,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: Text(
                track.title,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                p.basename(track.path),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        _audioTracks.removeAt(index);
                      });
                    },
                  ),
                  const Icon(Icons.drag_handle, color: Colors.white54),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: YomuConstants.accent),
        ),
      ),
    );
  }
}
