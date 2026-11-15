import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A book that just arrived with someone's notes. The reader greets it with
/// a welcome sheet offering to walk through those notes.
class SharedWelcome {
  final int bookId;
  final String? sharedBy;
  final int newNotes;
  final int newReplies;

  const SharedWelcome({
    required this.bookId,
    required this.sharedBy,
    required this.newNotes,
    required this.newReplies,
  });
}

final sharedWelcomeProvider = StateProvider<SharedWelcome?>((ref) => null);
