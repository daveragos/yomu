import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class AddBookFab extends StatelessWidget {
  final bool isMenuOpen;
  final AnimationController animationController;
  final VoidCallback onToggleMenu;
  final VoidCallback onScanFolder;
  final VoidCallback onImportFiles;

  const AddBookFab({
    super.key,
    required this.isMenuOpen,
    required this.animationController,
    required this.onToggleMenu,
    required this.onScanFolder,
    required this.onImportFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMenuOpen) ...[
          FloatingActionButton.small(
            onPressed: onScanFolder,
            backgroundColor: YomuConstants.surface,
            child: const Icon(Icons.folder_open, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            onPressed: onImportFiles,
            backgroundColor: YomuConstants.surface,
            child: const Icon(Icons.file_open, color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: onToggleMenu,
          backgroundColor: YomuConstants.accent,
          child: AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: animationController.value * (3.14159 / 4), // 45 degrees
                child: const Icon(Icons.add, color: Colors.black, size: 28),
              );
            },
          ),
        ),
      ],
    );
  }
}
