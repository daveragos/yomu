import 'package:flutter/material.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../core/constants.dart';

class ReadingHeader extends StatelessWidget {
  final Book book;
  final ReaderSettings settings;
  final String currentChapter;
  final dynamic pageInfo;
  final bool isSearching;
  final bool isSearchLoading;
  final bool isSearchResultsCollapsed;
  final int searchResultsCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onBackPressed;
  final VoidCallback onToggleSearch;
  final VoidCallback onClearSearch;
  final Function(String) onSearchSubmitted;
  final VoidCallback onToggleSearchResultsCollapse;
  final VoidCallback onToggleLock;
  final Widget? searchResultsOverlay;

  const ReadingHeader({
    super.key,
    required this.book,
    required this.settings,
    required this.currentChapter,
    required this.pageInfo,
    required this.isSearching,
    required this.isSearchLoading,
    required this.isSearchResultsCollapsed,
    required this.searchResultsCount,
    required this.searchController,
    required this.searchFocusNode,
    required this.onBackPressed,
    required this.onToggleSearch,
    required this.onClearSearch,
    required this.onSearchSubmitted,
    required this.onToggleSearchResultsCollapse,
    required this.onToggleLock,
    this.searchResultsOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: settings.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: settings.textColor,
                    ),
                    onPressed: onBackPressed,
                  ),
                  if (isSearching)
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        style: TextStyle(color: settings.textColor),
                        decoration: InputDecoration(
                          hintText: 'Search book...',
                          hintStyle: TextStyle(
                            color: settings.secondaryTextColor,
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close, color: settings.textColor),
                            onPressed: onClearSearch,
                          ),
                        ),
                        onTap: () {
                          if (isSearchResultsCollapsed) {
                            onToggleSearchResultsCollapse();
                          }
                        },
                        onSubmitted: onSearchSubmitted,
                      ),
                    )
                  else ...[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentChapter.toUpperCase(),
                            style: TextStyle(
                              color: settings.secondaryTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            book.title,
                            style: TextStyle(
                              color: settings.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.search_rounded,
                        color: settings.textColor,
                      ),
                      onPressed: onToggleSearch,
                    ),
                    if (book.filePath.toLowerCase().endsWith('.pdf'))
                      IconButton(
                        icon: Icon(
                          settings.lockState == ReaderLockState.none
                              ? Icons.lock_open_rounded
                              : settings.lockState == ReaderLockState.zoom
                              ? Icons.zoom_in_map_rounded
                              : Icons.lock_rounded,
                          color: settings.lockState != ReaderLockState.none
                              ? YomuConstants.accent
                              : settings.textColor,
                          size: 20,
                        ),
                        onPressed: onToggleLock,
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: settings.textColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: pageInfo is Widget
                          ? pageInfo
                          : Text(
                              pageInfo.toString(),
                              style: TextStyle(
                                color: settings.textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
              if (isSearching &&
                  searchResultsCount > 0 &&
                  !isSearchResultsCollapsed &&
                  searchResultsOverlay != null)
                searchResultsOverlay!,
              if (isSearchResultsCollapsed && searchResultsCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: onToggleSearchResultsCollapse,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: YomuConstants.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: YomuConstants.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: YomuConstants.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Show $searchResultsCount results',
                            style: TextStyle(
                              color: YomuConstants.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (isSearchLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
