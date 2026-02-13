class Highlight {
  final int? id;
  final int bookId;
  final String text;
  final String? note;
  final String color; // Hex string
  final DateTime createdAt;
  final String position; // CFI for EPUB, Page:Rect for PDF
  final String? chapterTitle;

  Highlight({
    this.id,
    required this.bookId,
    required this.text,
    this.note,
    required this.color,
    required this.createdAt,
    required this.position,
    this.chapterTitle,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'text': text,
      'note': note,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'position': position,
      'chapterTitle': chapterTitle,
    };
  }

  factory Highlight.fromMap(Map<String, dynamic> map) {
    return Highlight(
      id: map['id'],
      bookId: map['bookId'],
      text: map['text'],
      note: map['note'],
      color: map['color'],
      createdAt: DateTime.parse(map['createdAt']),
      position: map['position'],
      chapterTitle: map['chapterTitle'],
    );
  }

  Highlight copyWith({
    int? id,
    int? bookId,
    String? text,
    String? note,
    String? color,
    DateTime? createdAt,
    String? position,
    String? chapterTitle,
  }) {
    return Highlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      text: text ?? this.text,
      note: note ?? this.note,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
      chapterTitle: chapterTitle ?? this.chapterTitle,
    );
  }
}
