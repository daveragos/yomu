class Highlight {
  final int? id;
  final int bookId;
  final int chapterIndex;
  final String text;
  final String? note;
  final String color; // Hex string, e.g. '#E74C3C'
  final DateTime createdAt;

  const Highlight({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.text,
    this.note,
    required this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'text': text,
      'note': note,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Highlight.fromMap(Map<String, dynamic> map) {
    return Highlight(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      chapterIndex: map['chapterIndex'] as int,
      text: map['text'] as String,
      note: map['note'] as String?,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Highlight copyWith({
    int? id,
    int? bookId,
    int? chapterIndex,
    String? text,
    String? note,
    String? color,
    DateTime? createdAt,
  }) {
    return Highlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      text: text ?? this.text,
      note: note ?? this.note,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
