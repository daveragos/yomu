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
