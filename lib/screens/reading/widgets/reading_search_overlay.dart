import 'package:flutter/material.dart';
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
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                result.snippet,
                style: TextStyle(color: settings.textColor, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onResultTap(result),
            );
          },
        ),
      ),
    );
  }
}
