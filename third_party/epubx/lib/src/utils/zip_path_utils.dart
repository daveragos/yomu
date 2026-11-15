class ZipPathUtils {
  static String getDirectoryPath(String filePath) {
    var lastSlashIndex = filePath.lastIndexOf('/');
    if (lastSlashIndex == -1) {
      return '';
    } else {
      return filePath.substring(0, lastSlashIndex);
    }
  }

  static String? combine(String? directory, String? fileName) {
    var path;
    if (directory == null || directory == '') {
      path = fileName;
    } else {
      path = directory + '/' + fileName!;
    }
    return path == null ? null : normalize(path);
  }

  /// Resolves `.` and `..` segments of an archive path.
  ///
  /// Yomu patch: this used `Uri.parse(path).normalizePath().path`, which
  /// percent-encodes the result, so a file stored as `images/Screen shot.png`
  /// (or with any non-ASCII name) was looked up as `images/Screen%20shot.png`
  /// and the whole book failed to open. Archive entry names are stored as is.
  static String normalize(String path) {
    var segments = <String>[];
    for (var segment in path.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (segments.isNotEmpty) segments.removeLast();
        continue;
      }
      segments.add(segment);
    }
    var normalized = segments.join('/');
    return path.startsWith('/') ? '/' + normalized : normalized;
  }
}
