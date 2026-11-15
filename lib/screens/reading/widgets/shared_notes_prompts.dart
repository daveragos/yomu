import 'package:flutter/material.dart';
import '../../../core/yomu_colors.dart';
import '../../../models/book_model.dart';
import '../../../services/annotation_share_service.dart';

/// Asks whether to put notes made in another copy of [book] onto the
/// reader's copy, and does it. Returns the result when the notes were placed.
Future<SharedImportResult?> offerToPlaceNotes(
  BuildContext context, {
  required String pendingPath,
  required AnnotationPackageManifest manifest,
  required Book book,
}) async {
  final from = manifest.sharedBy ?? 'Someone';
  final colors = context.yomu;
  final place = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Put $from\'s notes on your copy?',
        style: TextStyle(color: colors.textPrimary),
      ),
      content: Text(
        'You have "${book.title}", but not the exact copy $from made '
        'notes in. Yomu can place the ${manifest.annotations.length} '
        '${manifest.annotations.length == 1 ? 'note' : 'notes'} by finding '
        'their passages in your copy. Any it can\'t find stay listed in '
        'Annotations.',
        style: TextStyle(color: colors.tint(0.70)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('NOT NOW', style: TextStyle(color: colors.tint(0.54))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'PLACE NOTES',
            style: TextStyle(color: colors.accent),
          ),
        ),
      ],
    ),
  );
  if (place != true) return null;
  try {
    return await AnnotationShareService().placePendingOn(pendingPath, book);
  } catch (e) {
    debugPrint('Failed to place notes on another copy: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not place the notes.')),
      );
    }
    return null;
  }
}
