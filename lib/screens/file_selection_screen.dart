import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/constants.dart';

class FileSelectionScreen extends StatefulWidget {
  final String directoryPath;
  final List<File> files;

  const FileSelectionScreen({
    super.key,
    required this.directoryPath,
    required this.files,
  });

  @override
  State<FileSelectionScreen> createState() => _FileSelectionScreenState();
}

class _FileSelectionScreenState extends State<FileSelectionScreen> {
  late List<bool> _selected;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.files.length, false);
  }

  void _toggleSelectAll(bool? value) {
    if (value == null) return;
    setState(() {
      _selectAll = value;
      for (int i = 0; i < _selected.length; i++) {
        _selected[i] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.where((s) => s).length;

    return Scaffold(
      backgroundColor: YomuConstants.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Files'),
            Text(
              p.basename(widget.directoryPath),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (selectedCount > 0)
            TextButton(
              onPressed: () {
                final result = <String>[];
                for (int i = 0; i < widget.files.length; i++) {
                  if (_selected[i]) {
                    result.add(widget.files[i].path);
                  }
                }
                Navigator.pop(context, result);
              },
              child: Text('Import ($selectedCount)'),
            ),
        ],
      ),
      body: Column(
        children: [
          CheckboxListTile(
            title: const Text('Select All'),
            value: _selectAll,
            onChanged: _toggleSelectAll,
            activeColor: YomuConstants.accent,
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: widget.files.length,
              itemBuilder: (context, index) {
                final file = widget.files[index];
                final fileName = p.basename(file.path);
                final relativePath = p.relative(
                  file.path,
                  from: widget.directoryPath,
                );
                final extension = p.extension(file.path).toLowerCase();

                return CheckboxListTile(
                  title: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    relativePath,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  secondary: Icon(
                    extension == '.epub'
                        ? Icons.book_outlined
                        : Icons.picture_as_pdf_outlined,
                    color: extension == '.epub' ? Colors.blue : Colors.red,
                  ),
                  value: _selected[index],
                  onChanged: (bool? value) {
                    setState(() {
                      _selected[index] = value ?? false;
                      _selectAll = _selected.every((s) => s);
                    });
                  },
                  activeColor: YomuConstants.accent,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
