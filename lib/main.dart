import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'screens/main_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: YomuApp()));
}

class YomuApp extends StatelessWidget {
  const YomuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yomu',
      debugShowCheckedModeBanner: false,
      theme: YomuTheme.darkTheme,
      home: const MainNavigation(),
    );
  }
}
