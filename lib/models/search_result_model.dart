class SearchResult {
  final int pageIndex; // For PDF (0-indexed) or EPUB chapter index
  final String title; // Chapter name or "Page X"
  final String snippet;
  final String query;
  final double? scrollProgress; // For EPUB scrolling estimation
  final dynamic metadata; // For extra info like PDF match objects

  SearchResult({
    required this.pageIndex,
    required this.title,
    required this.snippet,
    required this.query,
    this.scrollProgress,
    this.metadata,
  });
}
