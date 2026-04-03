class VocabularyLookup {
  final int? id;
  final int bookId;
  final String word;
  final DateTime timestamp;

  const VocabularyLookup({
    this.id,
    required this.bookId,
    required this.word,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'word': word,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory VocabularyLookup.fromMap(Map<String, dynamic> map) {
    return VocabularyLookup(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      word: map['word'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  VocabularyLookup copyWith({
    int? id,
    int? bookId,
    String? word,
    DateTime? timestamp,
  }) {
    return VocabularyLookup(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      word: word ?? this.word,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
