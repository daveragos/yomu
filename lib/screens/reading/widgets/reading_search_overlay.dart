import 'package:flutter/material.dart';
import '../../../core/breakpoints.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../models/search_result_model.dart';
import '../../../core/constants.dart';

class ReadingSearchOverlay extends StatelessWidget {
  final Book book;
  final ReaderSettings settings;
  final List<SearchResult> searchResults;
  final Function(SearchResult) onResultTap;

  const ReadingSearchOverlay({
    super.key,
    required this.book,
    required this.settings,
    required this.searchResults,
    required this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    // A wide window keeps the results under the search field at a readable
    // width, says how many there are, and uses desktop-sized text.
    final isWide = Breakpoints.isWide(context);
    final list = Container(
      constraints: BoxConstraints(maxHeight: isWide ? 480 : 400),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: settings.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: settings.textColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWide)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text(
                  '${searchResults.length} '
                  '${searchResults.length == 1 ? 'result' : 'results'}',
                  style: TextStyle(
                    color: settings.textColor.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: searchResults.length,
                separatorBuilder: (context, index) => Divider(
                  color: settings.textColor.withValues(alpha: 0.05),
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final result = searchResults[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      result.title,
                      style: TextStyle(
                        color: YomuConstants.accent,
                        fontSize: isWide ? 13 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text.rich(
                      _highlighted(result.snippet, result.query),
                      style: TextStyle(
                        color: settings.textColor,
                        fontSize: isWide ? 13 : 11,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onResultTap(result),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (!isWide) return list;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: list,
      ),
    );
  }

  /// [snippet] with every case-insensitive occurrence of [query] marked.
  TextSpan _highlighted(String snippet, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return TextSpan(text: snippet);
    final haystack = snippet.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    for (
      var i = haystack.indexOf(needle);
      i != -1;
      i = haystack.indexOf(needle, start)
    ) {
      if (i > start) spans.add(TextSpan(text: snippet.substring(start, i)));
      spans.add(
        TextSpan(
          text: snippet.substring(i, i + needle.length),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            backgroundColor: YomuConstants.accent.withValues(alpha: 0.25),
          ),
        ),
      );
      start = i + needle.length;
    }
    if (start < snippet.length)
      spans.add(TextSpan(text: snippet.substring(start)));
    return TextSpan(children: spans);
  }
}
