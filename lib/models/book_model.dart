class Book {
  final int? id;
  final String title;
  final String author;
  final String coverPath; // Local path to saved cover image
  final String filePath; // Local path to EPUB/PDF
  final double progress; // 0.0 to 1.0
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final bool isFavorite;
  final String? series;
  final String? tags; // Comma separated tags
  final String? folderPath;

  Book({
    this.id,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.filePath,
    this.progress = 0.0,
    required this.addedAt,
    this.lastReadAt,
    this.isFavorite = false,
    this.series,
    this.tags,
    this.folderPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverPath': coverPath,
      'filePath': filePath,
      'progress': progress,
      'addedAt': addedAt.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'isFavorite': isFavorite ? 1 : 0,
      'series': series,
      'tags': tags,
      'folderPath': folderPath,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      coverPath: map['coverPath'],
      filePath: map['filePath'],
      progress: (map['progress'] as num).toDouble(),
      addedAt: DateTime.parse(map['addedAt']),
      lastReadAt: map['lastReadAt'] != null
          ? DateTime.parse(map['lastReadAt'])
          : null,
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      series: map['series'],
      tags: map['tags'],
      folderPath: map['folderPath'],
    );
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? coverPath,
    String? filePath,
    double? progress,
    DateTime? addedAt,
    DateTime? lastReadAt,
    bool? isFavorite,
    String? series,
    String? tags,
    String? folderPath,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      progress: progress ?? this.progress,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isFavorite: isFavorite ?? this.isFavorite,
      series: series ?? this.series,
      tags: tags ?? this.tags,
      folderPath: folderPath ?? this.folderPath,
    );
  }
}
