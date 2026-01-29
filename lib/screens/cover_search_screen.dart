import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../services/book_service.dart';

class CoverSearchScreen extends StatefulWidget {
  final String initialQuery;

  const CoverSearchScreen({super.key, required this.initialQuery});

  @override
  State<CoverSearchScreen> createState() => _CoverSearchScreenState();
}

class _CoverSearchScreenState extends State<CoverSearchScreen> {
  late TextEditingController _searchController;
  List<String> _covers = [];
  bool _isLoading = false;
  final BookService _bookService = BookService();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=20&fields=items(volumeInfo/imageLinks)',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<String> results = [];
        if (data['items'] != null) {
          for (var item in data['items']) {
            final imageLinks = item['volumeInfo']?['imageLinks'];
            if (imageLinks != null) {
              // Prefer high quality if available
              String? link =
                  imageLinks['extraLarge'] ??
                  imageLinks['large'] ??
                  imageLinks['medium'] ??
                  imageLinks['thumbnail'] ??
                  imageLinks['smallThumbnail'];
              if (link != null) {
                // Ensure https and improve quality if possible
                link = link.replaceFirst('http://', 'https://');
                // Some links have &zoom=1, removing it or changing to 0 might help
                results.add(link);
              }
            }
          }
        }
        setState(() {
          _covers = results.toSet().toList(); // Remove duplicates
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectCover(String url) async {
    setState(() => _isLoading = true);
    final localPath = await _bookService.downloadCover(url);
    if (mounted) {
      setState(() => _isLoading = false);
      if (localPath != null) {
        Navigator.pop(context, localPath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download cover')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search for cover...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _performSearch),
        ],
      ),
      body: _isLoading && _covers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _covers.isEmpty
          ? const Center(child: Text('No covers found'))
          : Stack(
              children: [
                GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _covers.length,
                  itemBuilder: (context, index) {
                    final url = _covers[index];
                    return GestureDetector(
                      onTap: () => _selectCover(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: YomuConstants.surface,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  },
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}
