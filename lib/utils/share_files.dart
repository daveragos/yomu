import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shares [params] through the system share sheet.
///
/// Linux has no share sheet for files (share_plus throws there), so each
/// file is offered in the desktop's Save dialog instead, and a toast says
/// where it went.
Future<void> shareFiles(BuildContext context, ShareParams params) async {
  final files = params.files ?? const <XFile>[];
  if (!Platform.isLinux || files.isEmpty) {
    if (Platform.isIOS && params.sharePositionOrigin == null) {
      params = ShareParams(
        text: params.text,
        subject: params.subject,
        title: params.title,
        previewThumbnail: params.previewThumbnail,
        sharePositionOrigin: sharePopoverOrigin(context),
        uri: params.uri,
        files: params.files,
        fileNameOverrides: params.fileNameOverrides,
        downloadFallbackEnabled: params.downloadFallbackEnabled,
        mailToFallbackEnabled: params.mailToFallbackEnabled,
        excludedCupertinoActivities: params.excludedCupertinoActivities,
      );
    }
    await SharePlus.instance.share(params);
    return;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  for (final file in files) {
    final name = file.name.isNotEmpty ? file.name : p.basename(file.path);
    final dest = await FilePicker.platform.saveFile(
      dialogTitle:
          'Save ${p.extension(name).replaceFirst('.', '').toUpperCase()}',
      fileName: name,
    );
    if (dest == null) continue;
    await File(file.path).copy(dest);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Saved ${p.basename(dest)}'),
          action: SnackBarAction(
            label: 'Show folder',
            onPressed: () => launchUrl(Uri.file(p.dirname(dest))),
          ),
        ),
      );
  }
}

/// Where the share sheet points on an iPad, which shows it as a popover:
/// [context]'s widget, clipped to the screen, or the middle of the screen
/// when that widget is gone or off screen. share_plus refuses to share on
/// an iPad without a non-empty spot inside the screen.
@visibleForTesting
Rect sharePopoverOrigin(BuildContext context) {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  final box = context.mounted ? context.findRenderObject() : null;
  if (box is RenderBox && box.attached && box.hasSize) {
    final rect = (box.localToGlobal(Offset.zero) & box.size).intersect(screen);
    if (!rect.isEmpty) return rect;
  }
  return Rect.fromCenter(center: screen.center, width: 1, height: 1);
}
