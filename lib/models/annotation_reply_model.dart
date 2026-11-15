import 'highlight_model.dart';

/// A reply under someone's note, written here or shared back by a friend.
class AnnotationReply {
  final int? id;
  final int bookId;

  /// [Highlight.uid] of the note this answers.
  final String highlightUid;

  /// Stable id that survives sharing, so re-importing updates the reply.
  final String uid;

  /// Who wrote it; null for the reader's own replies.
  final String? author;
  final String text;
  final String? audioFile;
  final int? audioDurationMs;
  final String? audioWaveform;
  final DateTime createdAt;

  const AnnotationReply({
    this.id,
    required this.bookId,
    required this.highlightUid,
    required this.uid,
    this.author,
    required this.text,
    this.audioFile,
    this.audioDurationMs,
    this.audioWaveform,
    required this.createdAt,
  });

  bool get isMine => author == null;
  bool get hasAudio => audioFile != null && audioFile!.isNotEmpty;

  static String generateUid() => Highlight.generateUid();

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'bookId': bookId,
    'highlightUid': highlightUid,
    'uid': uid,
    'author': author,
    'text': text,
    'audioFile': audioFile,
    'audioDurationMs': audioDurationMs,
    'audioWaveform': audioWaveform,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AnnotationReply.fromMap(Map<String, dynamic> map) => AnnotationReply(
    id: map['id'] as int?,
    bookId: map['bookId'] as int,
    highlightUid: map['highlightUid'] as String,
    uid: map['uid'] as String,
    author: map['author'] as String?,
    text: map['text'] as String? ?? '',
    audioFile: map['audioFile'] as String?,
    audioDurationMs: map['audioDurationMs'] as int?,
    audioWaveform: map['audioWaveform'] as String?,
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  AnnotationReply copyWith({
    int? id,
    int? bookId,
    String? text,
    String? author,
    String? audioFile,
    int? audioDurationMs,
    String? audioWaveform,
    bool clearAudio = false,
  }) => AnnotationReply(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    highlightUid: highlightUid,
    uid: uid,
    author: author ?? this.author,
    text: text ?? this.text,
    audioFile: clearAudio ? null : audioFile ?? this.audioFile,
    audioDurationMs: clearAudio ? null : audioDurationMs ?? this.audioDurationMs,
    audioWaveform: clearAudio ? null : audioWaveform ?? this.audioWaveform,
    createdAt: createdAt,
  );
}
