import 'dart:math';

class Highlight {
  final int? id;
  final int bookId;
  final int chapterIndex;
  final String text;
  final String? note;
  final String color; // Hex string, e.g. '#E74C3C'
  final DateTime createdAt;
  final String position; // Granular position string (CFI or PDF offset)

  /// Stable id that survives sharing, so re-importing the same shared
  /// annotation updates it instead of duplicating it.
  final String? uid;

  /// File name (inside the annotation audio folder) of an attached voice note.
  final String? audioFile;
  final int? audioDurationMs;

  /// Loudness bars of the voice note (see VoiceWaveform), when recorded.
  final String? audioWaveform;

  /// Name of the reader who shared this annotation. Null for the user's own.
  final String? sharedBy;

  /// Left out when the book is shared.
  final bool isPrivate;

  /// How the highlight is tied to the text. Null: its position is exact.
  /// [anchorByText]: shared from another copy of the book, still to be found
  /// by its text. [anchorUnplaced]: its text wasn't found in this copy.
  final String? anchorState;

  static const anchorByText = 'text';
  static const anchorUnplaced = 'unplaced';

  const Highlight({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.text,
    this.note,
    required this.color,
    required this.createdAt,
    required this.position,
    this.uid,
    this.audioFile,
    this.audioDurationMs,
    this.audioWaveform,
    this.sharedBy,
    this.isPrivate = false,
    this.anchorState,
  });

  bool get needsPlacing => anchorState == anchorByText;
  bool get isUnplaced => anchorState == anchorUnplaced;

  bool get hasAudio => audioFile != null && audioFile!.isNotEmpty;
  bool get hasNote => note != null && note!.trim().isNotEmpty;
  bool get isShared => sharedBy != null;

  static String generateUid() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'text': text,
      'note': note,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'position': position,
      'uid': uid,
      'audioFile': audioFile,
      'audioDurationMs': audioDurationMs,
      'audioWaveform': audioWaveform,
      'sharedBy': sharedBy,
      'isPrivate': isPrivate ? 1 : 0,
      'anchorState': anchorState,
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
      position: map['position'] as String? ?? '',
      uid: map['uid'] as String?,
      audioFile: map['audioFile'] as String?,
      audioDurationMs: map['audioDurationMs'] as int?,
      audioWaveform: map['audioWaveform'] as String?,
      sharedBy: map['sharedBy'] as String?,
      isPrivate: (map['isPrivate'] as int? ?? 0) == 1,
      anchorState: map['anchorState'] as String?,
    );
  }

  static const Object _unset = Object();

  Highlight copyWith({
    int? id,
    int? bookId,
    int? chapterIndex,
    String? text,
    String? note,
    String? color,
    DateTime? createdAt,
    String? position,
    String? uid,
    Object? audioFile = _unset,
    Object? audioDurationMs = _unset,
    Object? audioWaveform = _unset,
    Object? sharedBy = _unset,
    bool? isPrivate,
    Object? anchorState = _unset,
  }) {
    return Highlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      text: text ?? this.text,
      note: note ?? this.note,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
      uid: uid ?? this.uid,
      audioFile: audioFile == _unset ? this.audioFile : audioFile as String?,
      audioDurationMs: audioDurationMs == _unset
          ? this.audioDurationMs
          : audioDurationMs as int?,
      audioWaveform: audioWaveform == _unset
          ? this.audioWaveform
          : audioWaveform as String?,
      sharedBy: sharedBy == _unset ? this.sharedBy : sharedBy as String?,
      isPrivate: isPrivate ?? this.isPrivate,
      anchorState: anchorState == _unset
          ? this.anchorState
          : anchorState as String?,
    );
  }
}
