class Bookmark {
  final int? id;
  final int bookId;
  final String title; // Chapter name or user description
  final double progress; // 0.0 to 1.0
  final DateTime createdAt;
  final String position; // Granular position string (CFI or PDF offset)

  Bookmark({
    this.id,
    required this.bookId,
    required this.title,
    required this.progress,
    required this.createdAt,
    required this.position,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
      'position': position,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'],
      bookId: map['bookId'],
      title: map['title'],
      progress: (map['progress'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
      position: map['position'],
    );
  }
}
