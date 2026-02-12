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
  final String? genre;
  final int
  currentPage; // Current page number (0-indexed for PDFs, estimated for EPUBs)
  final int totalPages; // Total pages in the book
  final int estimatedReadingMinutes; // Estimated time to complete
  final String?
  lastPosition; // Granular position string (e.g., CFI for EPUB, offset for PDF)
  final String? audioPath; // Local path to associated audio file
  final int? audioLastPosition; // Last playback position in milliseconds
  final String? contentHash; // MD5 hash of the file content
  final bool isDeleted;

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
    this.genre = 'Unknown',
    this.currentPage = 0,
    this.totalPages = 0,
    this.estimatedReadingMinutes = 0,
    this.lastPosition,
    this.audioPath,
    this.audioLastPosition,
    this.contentHash,
    this.isDeleted = false,
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
      'genre': genre,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'estimatedReadingMinutes': estimatedReadingMinutes,
      'lastPosition': lastPosition,
      'audioPath': audioPath,
      'audioLastPosition': audioLastPosition,
      'contentHash': contentHash,
      'isDeleted': isDeleted ? 1 : 0,
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
      genre: map['genre'] ?? 'Unknown',
      currentPage: map['currentPage'] as int? ?? 0,
      totalPages: map['totalPages'] as int? ?? 0,
      estimatedReadingMinutes: map['estimatedReadingMinutes'] as int? ?? 0,
      lastPosition: map['lastPosition'],
      audioPath: map['audioPath'],
      audioLastPosition: map['audioLastPosition'] as int?,
      contentHash: map['contentHash'],
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
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
    String? genre,
    int? currentPage,
    int? totalPages,
    int? estimatedReadingMinutes,
    String? lastPosition,
    String? audioPath,
    int? audioLastPosition,
    String? contentHash,
    bool? isDeleted,
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
      genre: genre ?? this.genre,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      estimatedReadingMinutes:
          estimatedReadingMinutes ?? this.estimatedReadingMinutes,
      lastPosition: lastPosition ?? this.lastPosition,
      audioPath: audioPath ?? this.audioPath,
      audioLastPosition: audioLastPosition ?? this.audioLastPosition,
      contentHash: contentHash ?? this.contentHash,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
