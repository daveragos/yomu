# epubx, vendored for Yomu

`lib/`, `LICENSE` and `pubspec.yaml` are upstream
[rbcprolabs/epubx.dart](https://github.com/rbcprolabs/epubx.dart) at commit
`1c0347b20c9123866bff760f8571ec50fefb037d` (unreleased 4.0.1, which moves to
`image` 4 as pdfrx 2.12 requires), with the patch below.

## Patches

- `lib/src/utils/zip_path_utils.dart`: `combine` resolved `.`/`..` with
  `Uri.parse(path).normalizePath().path`, which percent-encodes the path.
  Books whose files have spaces or non-ASCII characters in their names then
  failed to open ("file OPS/images/Screen%20shot….png not found in
  archive"). `normalize` now resolves the segments without encoding.

When upstream fixes this, point `dependency_overrides` in the app's
`pubspec.yaml` back at it and delete this folder.
