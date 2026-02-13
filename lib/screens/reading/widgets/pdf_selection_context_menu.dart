import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfSelectionContextMenu extends StatelessWidget {
  final List<PdfTextRanges> selections;
  final Function(Color) onHighlight;
  final Rect? position;

  const PdfSelectionContextMenu({
    super.key,
    required this.selections,
    required this.onHighlight,
    this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: position?.left ?? 0,
          right: position == null ? 0 : null,
          top: (position?.top ?? 100) - 60, // Position above the selection
          child: position == null ? Center(child: _buildMenu()) : _buildMenu(),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ColorOption(
            color: Colors.yellow,
            onTap: () => onHighlight(Colors.yellow),
          ),
          _ColorOption(
            color: Colors.green,
            onTap: () => onHighlight(Colors.green),
          ),
          _ColorOption(
            color: Colors.blue,
            onTap: () => onHighlight(Colors.blue),
          ),
          _ColorOption(
            color: Colors.pink,
            onTap: () => onHighlight(Colors.pink),
          ),
          _ColorOption(
            color: Colors.orange,
            onTap: () => onHighlight(Colors.orange),
          ),
        ],
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorOption({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}
