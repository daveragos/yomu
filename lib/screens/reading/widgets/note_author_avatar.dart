import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/yomu_colors.dart';

/// Colour that stands for a reader across the app: their avatar, markers
/// next to their highlights, and their filter chip. The reader's own notes
/// (no [name]) use the accent colour: pass the theme's as [accent] where
/// there is a context.
Color noteAuthorColor(String? name, {Color accent = YomuConstants.accent}) {
  if (name == null) return accent;
  const palette = [
    Color(0xFF5DADE2),
    Color(0xFFF5B041),
    Color(0xFF58D68D),
    Color(0xFFEC7063),
    Color(0xFFAF7AC5),
    Color(0xFF45B39D),
    Color(0xFFF1948A),
    Color(0xFF85C1E9),
  ];
  final hash = name.toLowerCase().codeUnits.fold<int>(
    7,
    (h, c) => (h * 31 + c) & 0x7fffffff,
  );
  return palette[hash % palette.length];
}

/// "You" for the reader's own notes, else the sharer's name.
String noteAuthorName(String? name) => name ?? 'You';

/// A round badge with a reader's first initial.
class NoteAuthorAvatar extends StatelessWidget {
  final String? name;
  final double size;

  const NoteAuthorAvatar({super.key, required this.name, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final color = noteAuthorColor(name, accent: context.yomu.accent);
    final label = noteAuthorName(name).trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label.isEmpty ? '?' : label.characters.first.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
