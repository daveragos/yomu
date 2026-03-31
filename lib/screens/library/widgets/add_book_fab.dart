import 'package:flutter/material.dart';
import '../../../core/constants.dart';

class AddBookFab extends StatelessWidget {
  final VoidCallback onPressed;

  const AddBookFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'fab-add',
      onPressed: onPressed,
      backgroundColor: YomuConstants.accent,
      child: const Icon(Icons.add, color: Colors.black, size: 28),
    );
  }
}
