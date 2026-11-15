import 'package:flutter/material.dart';
import '../../../core/yomu_colors.dart';

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
      backgroundColor: context.yomu.accent,
      child: Icon(Icons.add, color: context.yomu.onAccent, size: 28),
    );
  }
}
