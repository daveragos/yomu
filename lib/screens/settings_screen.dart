import 'package:flutter/material.dart';
import '../core/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YomuConstants.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Settings coming soon!',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}
